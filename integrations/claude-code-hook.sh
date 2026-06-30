#!/usr/bin/env bash
#
# NotchPulse — Claude Code hook bridge
# ------------------------------------
# Reads a Claude Code hook event from stdin (JSON) and forwards a compact
# NotchPulse event to the local activity server.
#
# Install: see integrations/settings.example.json — copy the "hooks" block into
# your ~/.claude/settings.json and point the command paths at this script.
#
# IMPORTANT: The Claude Code hook input schema can change between versions.
# Verify field names (hook_event_name, tool_name, session_id, ...) against the
# current docs at https://docs.claude.com before relying on this in production.
#
# This script is intentionally dependency-light: it uses jq if present, then
# python3, then a regex fallback — so it works even on a bare machine. It must
# NEVER fail the tool call, so it always exits 0.

set -u

PORT="${NOTCHPULSE_PORT:-7842}"
URL="http://127.0.0.1:${PORT}/event"

# First arg selects the lifecycle phase. Defaults to reading hook_event_name.
PHASE="${1:-}"

# Read the hook payload from stdin (may be empty).
PAYLOAD="$(cat 2>/dev/null || true)"

# --- field extraction (jq -> python3 -> regex) ------------------------------
json_get() {
  # $1 = key name. Echoes the string value or empty.
  local key="$1"
  if [ -z "$PAYLOAD" ]; then return 0; fi
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get(sys.argv[1], "")
    if not isinstance(v, str):
        v = "" if v is None else str(v)
    sys.stdout.write(v)
except Exception:
    pass
' "$key" 2>/dev/null
    return 0
  fi
  # Crude regex fallback: first "key":"value" match.
  printf '%s' "$PAYLOAD" \
    | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
}

TOOL="$(json_get tool_name)"
SESSION="$(json_get session_id)"
HOOK_NAME="$(json_get hook_event_name)"

# Fall back to the hook name from stdin if no phase arg was passed.
if [ -z "$PHASE" ]; then PHASE="$HOOK_NAME"; fi

# Group all events from one Claude Code session under a single notch activity.
ID="${SESSION:-claude-code}"

# --- map Claude Code phase -> NotchPulse event ------------------------------
EVENT=""
DETAIL=""
TITLE="Claude Code"
case "$PHASE" in
  prompt|UserPromptSubmit)
    # Fires the instant you hit enter — so the notch lights up immediately,
    # even while the model is still thinking (before any tool call).
    EVENT="start"
    DETAIL="Thinking…"
    ;;
  pre|PreToolUse)
    EVENT="start"
    DETAIL="${TOOL:+Running ${TOOL}}"
    ;;
  post|PostToolUse)
    EVENT="progress"
    DETAIL="${TOOL:+${TOOL} done}"
    ;;
  stop|Stop|SubagentStop)
    EVENT="complete"
    DETAIL="Session finished"
    ;;
  fail|Error)
    EVENT="fail"
    DETAIL="${TOOL:+${TOOL} failed}"
    ;;
  *)
    # Unknown phase: treat as a progress ping so we never silently drop it.
    EVENT="progress"
    DETAIL="$PHASE"
    ;;
esac

# --- JSON-escape helper -----------------------------------------------------
esc() {
  # Escape backslashes and double quotes for embedding in JSON.
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

BODY="{\"event\":\"$(esc "$EVENT")\",\"id\":\"$(esc "$ID")\",\"title\":\"$(esc "$TITLE")\",\"source\":\"Claude Code\""
if [ -n "$DETAIL" ]; then
  BODY="${BODY},\"detail\":\"$(esc "$DETAIL")\""
fi
# Owning terminal/editor for one-tap Focus from the notch. Set NOTCHPULSE_APP to
# your terminal's bundle id or name, e.g. "com.apple.Terminal", "iTerm", "Code".
if [ -n "${NOTCHPULSE_APP:-}" ]; then
  BODY="${BODY},\"app\":\"$(esc "$NOTCHPULSE_APP")\""
fi
BODY="${BODY}}"

# Fire and forget — short timeout, never block or fail the tool call.
curl -s --max-time 1 "$URL" -d "$BODY" >/dev/null 2>&1 || true

exit 0
