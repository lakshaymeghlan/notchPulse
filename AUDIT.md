# NotchPulse — Engineering Audit & Enhancement Plan

_Snapshot: v0.2.0 (build 2), branch `development`, macOS 14+, ~6.5k lines Swift + Next.js site. No automated tests._

This is an audit of the current codebase and a prioritized plan for what to build,
fix, and cut next. Findings are anchored to real files.

---

## 1. Health snapshot

**Solid foundation.** The data flow is clean and single-owner:

```
POST 127.0.0.1:7842 → ActivityServer → ActivityStore.apply() → SwiftUI NotchView
```

- `ActivityStore` (`@MainActor`, all mutation through `apply(_:)`) is well-designed:
  cumulative-max on tokens/cost so meters never run backward, stale-running prune,
  success linger, injectable clock. This is the strongest file in the repo.
- `ActivityServer` is appropriately paranoid: loopback-only (`requiredLocalEndpoint`),
  64 KB body cap, hand-rolled HTTP that 4xx's on bad input instead of crashing.
- The event wire format is tolerant (every field but `event` optional) — good contract
  hygiene for a boundary tools POST to.

**Where the weight is.** Two files hold half the codebase and most of the risk:

| File | Lines | Note |
|------|------:|------|
| `Widgets.swift` | 1487 | View monolith — everything not in NotchView |
| `NotchView.swift` | 821 | Collapsed/expanded notch + Confetti + layout math |
| `PulseFace.swift` | 417 | **Mostly dormant** — the abandoned mascot pivot |
| `NotchWindowController.swift` | 554 | Panel/window/pointer logic |

---

## 2. Findings (by severity)

### 🔴 High — worth fixing before the next release

**F1. Free-text approval is a dead-end round-trip.**
The app fully captures a typed reply — `ApprovalStore.decide(id, allow:, text:)`
([ApprovalStore.swift:30](Sources/ApprovalStore.swift#L30)) and `/decision` returns
it (`DecisionResponse.text`, [ActivityServer.swift:215](Sources/ActivityServer.swift#L215)).
But `approve.sh` only pattern-matches `"allow"`/`"deny"` and **never reads `text`**
([integrations/approve.sh:92-95](integrations/approve.sh#L92)). So the "type anything
from the notch" feature the UI advertises is silently dropped before it reaches the agent.
Either wire `text` into the hook output (e.g. `permissionDecisionReason` or additionalContext)
or remove the TextField so the UI stops promising something that doesn't land.

**F2. `approve.sh` decision parsing is fragile.**
It greps the whole JSON body for the substring `"allow"` / `"deny"`. Once F1 is fixed
and free-text flows through, a reply containing the word "allow"/"deny" can false-match
the decision. Parse the `decision` field specifically (`jq -r .decision`, or match
`"decision":"allow"`), not the raw body.

**F3. Zero automated tests.**
`ActivityStore` literally documents "injectable clock so the implementation stays testable"
([ActivityStore.swift:105](Sources/ActivityStore.swift#L105)) — and then nothing uses it.
The logic most likely to break silently is exactly the testable, pure part: `resolveID`,
cumulative-max merge, stale-prune cutoff, `summaryLine`, `etaSeconds`, and the HTTP parser's
partial-body handling. One `XCTest` target over those five functions catches the regressions
that screenshots never will.

### 🟡 Medium — real, not urgent

**F4. CORS is wildcard on gating endpoints.**
`Access-Control-Allow-Origin: *` ([ActivityServer.swift:201](Sources/ActivityServer.swift#L201))
is fine for the cosmetic `/event` + `/ping` the website uses. But it's also open on `/approve`
and `/decision`. Any website you visit can, from the browser, poll `/decision` or spam
`/approve` on your loopback. It can't *auto-approve* (that needs UI interaction), so blast
radius is low — but restrict CORS to `/ping` + `/event`, or drop it from the approval paths.

**F5. No auth token on the server.**
Any local process can `POST /event` (cosmetic spam) or `POST /approve` (fake banners).
Loopback bounds this to the local machine, which is the right call for a personal tool —
but on a shared/multi-user Mac it's exposed. A per-install token in a header (written to
the settings the hook reads) closes it without adding a dependency.

**F6. Stale-running prune can kill a long, quiet task.**
`staleRunningTimeout = 90s` ([ActivityStore.swift:98](Sources/ActivityStore.swift#L98)):
a legitimately long tool that goes 90s between events vanishes from the notch. Fine for
Claude Code (frequent hooks), risky for CI or a long build posting sparse `progress`.
Consider a lightweight heartbeat (`progress` with unchanged value keeps it alive) or a
longer timeout for tasks that have ever reported `progress`.

**F7. Collapsed panel eats clicks (known limitation, still open).**
Per CLAUDE.md: the transparent rounded corners of the collapsed panel accept mouse events
across the whole frame. Toggle `ignoresMouseEvents` when idle, or shrink the collapsed hit
region to the pill shape. This is the most user-visible rough edge day-to-day.

**F8. Two PreToolUse hooks both fire.**
`approve.sh` and `claude-code-hook.sh` are both registered on PreToolUse. Confirm ordering
and that the passive event-poster doesn't race or double-count against the approval gate.
Document the intended composition in `settings.example.json`.

### 🟢 Low — code health / cleanup

**F9. ~550 lines of dormant mascot code.**
`PulseFace.swift` (417) + `UserActivityMonitor.swift` (133) back the abandoned face/mascot
direction. `NotchFace`, the `Mood` state machine, and typing-intensity tracking are no longer
on the display path. Delete or move behind a clearly-marked `// experimental` fence — right
now it reads as live architecture and misleads the next reader (including future-you).

**F10. `Widgets.swift` is a 1487-line grab-bag.**
Not a bug, but it's where velocity goes to die. Split by widget family (clock/calendar/system/
teleprompter) when you next touch it. Don't do it speculatively — split the file you're already
editing.

**F11. `self.port` captured non-weakly in the listener state handler.**
[ActivityServer.swift:52](Sources/ActivityServer.swift#L52) captures `self` strongly in
`stateUpdateHandler` (the `newConnectionHandler` correctly uses `[weak self]`). Server lives
for the app lifetime so it won't leak in practice, but it's an inconsistency worth a `[weak self]`.

---

## 3. Enhancement roadmap

Building on the CLAUDE.md roadmap, ordered by value-to-effort.

### Quick wins (hours)
1. **Finish free-text approval (F1)** — the feature is 90% built; the last 10% is one hook edit.
2. **Multi-display placement** — today the notch follows `NSScreen.main` only. Track the screen
   with the active window, or let the user pin it. Common ask for external-monitor setups.
3. **Auth token (F5)** + **scoped CORS (F4)** — small, closes the two security gaps together.
4. **Sound/speech finish feedback config** — `FinishFeedback` exists; expose volume/voice/off
   in `WidgetSettings`.

### Medium bets (days)
5. **CI/GitHub Actions feed** — no app code needed (any job can `POST /event`); ship a turnkey
   GH Actions poller + a documented recipe. High leverage: turns the notch into a build monitor.
6. **Test target (F3)** — pure-logic XCTest over store + HTTP parser. Pays for itself the first
   time you refactor NotchView again.
7. **Editor extensions** — VS Code / Cursor / Zed posting to the same loopback API (separate repos).
   The contract already exists; this is the growth path.
8. **Click-through fix (F7)** — polish that removes a daily papercut.

### Bigger bets (weeks / needs external pieces)
9. **Auto-update (Sparkle)** — currently manual re-download only. Deferred in CLAUDE.md; the
   right time is before the userbase grows past "people who'll re-download."
10. **Do-Not-Disturb while agents run** — no public Focus API; requires a user-installed Shortcut.
    Ship the Shortcut + a toggle, or skip and document why.
11. **Persistence / history** — activities are in-memory only. A rolling log ("what ran today,
    tokens/cost totals") is a natural expansion of the token meter you already have.

---

## 4. The one-line call

**Do next:** finish free-text approval (F1+F2), add the pure-logic test target (F3), then the
CI feed (#5) — that's the highest-leverage sequence. **Cut:** the dormant mascot code (F9), so
the codebase stops advertising a direction you already abandoned.
