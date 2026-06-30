#!/usr/bin/env bash
#
# NotchPulse — Approve-from-the-notch (Claude Code PreToolUse hook)
# -----------------------------------------------------------------
# Sends a permission request to the NotchPulse notch and waits for you to tap
# Approve / Deny right on the notch — no terminal context-switch.
#
# Wire it up as a PreToolUse hook (see integrations/settings.example.json). It
# emits the Claude Code `permissionDecision` JSON on stdout:
#   { "hookSpecificOutput": { "hookEventName": "PreToolUse",
#       "permissionDecision": "allow" | "deny", "permissionDecisionReason": "…" } }
#
# Fail-open by design: if NotchPulse isn't running, or the request times out,
# it stays out of the way (emits nothing) so Claude Code's normal permission
# flow takes over. It must NEVER hard-fail a tool call, so it always exits 0.
#
# Tunables (env):
#   NOTCHPULSE_PORT            loopback port (default 7842)
#   NOTCHPULSE_APPROVE_TIMEOUT seconds to wait for a decision (default 60)
#   NOTCHPULSE_APPROVE_DEFAULT what to do on timeout: "ask" (default) | "allow"
#
# The Claude Code hook input schema can change between versions — verify field
# names against https://docs.claude.com before relying on this in production.

set -u

PORT="${NOTCHPULSE_PORT:-7842}"
BASE="http://127.0.0.1:${PORT}"
TIMEOUT="${NOTCHPULSE_APPROVE_TIMEOUT:-60}"
ON_TIMEOUT="${NOTCHPULSE_APPROVE_DEFAULT:-ask}"

PAYLOAD="$(cat 2>/dev/null || true)"

# --- field extraction (jq -> python3 -> regex) ------------------------------
# Supports dotted paths like "tool_input.command".
json_get() {
  local key="$1"
  if [ -z "$PAYLOAD" ]; then return 0; fi
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | jq -r --arg k "$key" 'getpath($k|split(".")) // empty' 2>/dev/null
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for part in sys.argv[1].split("."):
        d = d.get(part, "") if isinstance(d, dict) else ""
    sys.stdout.write(d if isinstance(d, str) else ("" if d is None else str(d)))
except Exception:
    pass
' "$key" 2>/dev/null
    return 0
  fi
  local leaf="${key##*.}"
  printf '%s' "$PAYLOAD" \
    | grep -o "\"$leaf\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
}

TOOL="$(json_get tool_name)"
SESSION="$(json_get session_id)"
# Best-effort human-readable command/summary for the notch.
CMD="$(json_get tool_input.command)"
[ -z "$CMD" ] && CMD="$(json_get tool_input.file_path)"
[ -z "$CMD" ] && CMD="$(json_get tool_input.url)"
[ -z "$CMD" ] && CMD="$TOOL"

# Unique id per request so repeated calls don't collide.
ID="${SESSION:-cc}-$$-${RANDOM}"

emit() {
  # $1 = allow|deny  $2 = reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"
}

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Bail out fail-open if the app isn't reachable.
if ! curl -s --max-time 1 "${BASE}/ping" >/dev/null 2>&1; then
  exit 0
fi

BODY="{\"id\":\"$(esc "$ID")\",\"tool\":\"$(esc "$TOOL")\",\"command\":\"$(esc "$CMD")\",\"source\":\"$(esc "${CLAUDE_AGENT_NAME:-Claude Code}")\"}"
curl -s --max-time 2 "${BASE}/approve" -d "$BODY" >/dev/null 2>&1 || exit 0

# Poll for the decision.
DEADLINE=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  RESP="$(curl -s --max-time 2 "${BASE}/decision?id=${ID}" 2>/dev/null || true)"
  case "$RESP" in
    *'"allow"'*) emit "allow" "Approved on the notch"; exit 0 ;;
    *'"deny"'*)  emit "deny"  "Denied on the notch";   exit 0 ;;
  esac
  sleep 1
done

# Timed out waiting. Fail-open: hand back to Claude Code's normal flow ("ask"),
# or auto-allow if the user opted in.
if [ "$ON_TIMEOUT" = "allow" ]; then
  emit "allow" "NotchPulse timed out — auto-approved"
fi
exit 0
