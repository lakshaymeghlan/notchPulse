# CLAUDE.md — NotchPulse

Guidance for AI agents (and humans) working in this repo.

## What this is

A menu-bar-only macOS app (macOS 14+) that renders a Dynamic-Island-style pill
over the MacBook notch. Local tools POST JSON events to a loopback HTTP server;
the notch shows live activity. **Clean-room, original, commercial** — never copy
from Boring Notch, MacNotch, or any GPL/CC-BY-NC project.

## Build

Project is generated from `project.yml` via XcodeGen. After editing sources or
`project.yml`:

```bash
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # if needed
xcodebuild -project NotchPulse.xcodeproj -scheme NotchPulse \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

The `.xcodeproj` is git-ignored; regenerate it. `DEVELOPER_DIR` is only needed
when `xcode-select` points at the Command Line Tools instead of full Xcode.

## Architecture & data flow

```
POST 127.0.0.1:7842/event → ActivityServer → ActivityStore.apply(event) → SwiftUI NotchView
```

- **ActivityServer** (`Network.framework`, `NWListener`) is loopback-only via
  `requiredLocalEndpoint = 127.0.0.1`. It hand-parses just enough HTTP/1.1
  (request line + headers + Content-Length body). It is defensive: malformed
  input returns 4xx and never crashes the app. **Never bind to 0.0.0.0.**
- **ActivityStore** is `@MainActor`. All mutation funnels through `apply(_:)`.
  Activities are keyed by `id`; missing ids resolve to the most-recent running
  activity or a fresh UUID. `complete` schedules an ~8s auto-prune (cancelled if
  the activity is updated again); `fail` persists until cleared.
- **NotchWindowController** owns a borderless non-activating `NSPanel`
  (`.statusBar` level, joins all spaces + fullScreenAuxiliary). Collapsed, the
  panel matches the *physical notch* exactly (measured via `safeAreaInsets.top`
  for height and the `auxiliaryTopLeft/RightArea` gap for width) and sits flush
  to the very top of `NSScreen.main.frame`, overlaying the hardware notch.
  Expanded, it grows wider and downward from the same top edge. Repositions on
  `didChangeScreenParametersNotification`; animates ~0.22s ease-out.
  - **Expansion triggers:** hover (`NotchState.isHovering`) and a ~3.5s auto
    "peek" (`isPeeking`) fired on new activity. `isExpanded = hovering || peeking`.
  - The peek is driven by `ActivityStore.onActivity` (an explicit callback fired
    at the end of `apply()`), hopped onto a fresh main-queue turn. We deliberately
    do **not** observe `$activities` for this — that sink fires mid-`willSet` and
    proved unreliable for driving the panel resize.
- **NotchView** draws the `NotchShape` (flush square top, rounded bottom — the
  hardware-notch silhouette). Collapsed: idle ⇒ pure black (blends with the
  notch); active ⇒ status glyph + count in the "ears" straddling the camera.
  Expanded: a card whose top padding clears the camera/sensor strip.

## Build/run gotcha

`open`-ing the wrong DerivedData bundle silently runs a **stale binary**. Always
launch the exact product path:
`xcodebuild ... -showBuildSettings | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2}'`
— never `ls DerivedData/NotchPulse-* | head -1` (it can pick an old bundle).

## Event API

See README. Server is the contract boundary — keep it tolerant of unknown
fields and bad input.

## Rough edges / known limitations

- **Click-through:** the panel currently accepts mouse events everywhere within
  its frame (needed for hover). The transparent rounded corners can still eat
  clicks. TODO: shrink the collapsed hit area to the pill shape, or toggle
  `ignoresMouseEvents` when idle. Tracked but not yet done.
- **Notch sizing:** the collapsed surface now matches the measured notch
  (`NotchGeometry` width + `safeAreaInsets.top` height). The `NotchShape` top
  fillet / bottom radius are hand-tuned; revisit against more hardware.
- **Non-notched / external displays:** `NotchGeometry.hasNotch` checks
  `safeAreaInsets.top`. On non-notched Macs we render a top-center floating pill
  (the same black rounded surface). Multi-display: we currently follow
  `NSScreen.main`; per-display placement isn't implemented.
- **Hook schema drift:** Claude Code hook fields can change between versions;
  the bridge script extracts defensively and the README points at the docs.

## Feature roadmap

Shipped:
- ✅ Multiple concurrent agent lanes (`AgentSection`) + Agent Race view.
- ✅ Token + cost meter (`TokenMeterSection`) and per-task ETA.
- ✅ Completion summary — files touched, +/- diff, tests (`Activity.summaryLine`).
- ✅ Click-to-focus the owning terminal/editor (`FocusAppButton` / `AppFocus`,
  driven by the event `app` field).
- ✅ Sound + speech on finish (`FinishFeedback`).
- ✅ Approve-from-the-notch (`ApprovalStore`, `/approve` + `/decision`).

Not yet / out of core scope:
- Auto Do-Not-Disturb while agents run — **no public macOS API** to set Focus
  programmatically; would require a user-installed Shortcut. Deferred.
- GitHub Actions / CI feed — no app code needed: any CI job can `POST /event`
  with `progress`/`tokens`/etc. A turnkey GH poller (needs a token) is future work.
- VS Code / Cursor / Zed extensions — separate repos that post to the same
  loopback event API; not part of the core app.

## Conventions

- AppKit for windowing, SwiftUI for views. `@MainActor` on anything touching the
  store or UI.
- No third-party Swift deps in the core (Sparkle/payment libs come much later
  and stay out of the event path).
- Match the surrounding comment density and naming. Keep the server minimal —
  it is not a general web server.
