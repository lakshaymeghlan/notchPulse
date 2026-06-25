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
  (`.statusBar` level, joins all spaces + fullScreenAuxiliary). It pins the
  panel flush to the top-center of `NSScreen.main.frame`, repositions on
  `didChangeScreenParametersNotification`, and animates expand/collapse (~0.22s
  ease-out) by resizing while holding the top-center anchor.
- **NotchView** renders the collapsed pill (spinner/✓/✗ + count) and the
  expanded card; hover toggles `NotchState.isExpanded`, which the controller
  observes to resize the panel.

## Event API

See README. Server is the contract boundary — keep it tolerant of unknown
fields and bad input.

## Rough edges / known limitations

- **Click-through:** the panel currently accepts mouse events everywhere within
  its frame (needed for hover). The transparent rounded corners can still eat
  clicks. TODO: shrink the collapsed hit area to the pill shape, or toggle
  `ignoresMouseEvents` when idle. Tracked but not yet done.
- **Notch sizing:** `NotchGeometry` derives notch width from
  `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`, falling back to ~200pt. Tune
  against real hardware.
- **Non-notched / external displays:** `NotchGeometry.hasNotch` checks
  `safeAreaInsets.top`. On non-notched Macs we render a top-center floating pill
  (the same black rounded surface). Multi-display: we currently follow
  `NSScreen.main`; per-display placement isn't implemented.
- **Hook schema drift:** Claude Code hook fields can change between versions;
  the bridge script extracts defensively and the README points at the docs.

## Feature roadmap (each behind a settings toggle, post-MVP)

- Multiple concurrent agent lanes.
- Token + cost ticker and ETA.
- Completion summary (files touched, tests passed, diff stats).
- Click-to-focus the owning terminal/editor.
- Auto Do-Not-Disturb while agents run.
- GitHub Actions / CI feed.
- Sound on finish.
- VS Code / Cursor / Zed extensions posting to the same server.

## Conventions

- AppKit for windowing, SwiftUI for views. `@MainActor` on anything touching the
  store or UI.
- No third-party Swift deps in the core (Sparkle/payment libs come much later
  and stay out of the event path).
- Match the surrounding comment density and naming. Keep the server minimal —
  it is not a general web server.
