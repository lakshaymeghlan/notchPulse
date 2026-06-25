# NotchPulse

A menu-bar-only macOS app that turns the MacBook notch into a live-activity
surface — a Dynamic-Island-style pill for your desktop tools. External tools
`POST` small JSON events to a local server; the notch shows a running pill that
expands on hover and flips to success/failure when work finishes.

The first integration is a Claude Code hook, but the event API is tool-agnostic:
anything that can `curl` can drive the notch.

- **macOS 14+**, Swift 5.9+, AppKit windowing + SwiftUI views.
- Event server uses **Network.framework** and binds to **`127.0.0.1` only**.
- No third-party Swift dependencies in the core.
- Menu-bar-only: `.accessory` activation policy, `LSUIElement`, no Dock icon.

---

## Build & run

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) so it stays reproducible.

```bash
# 1. Install the generator (one-time)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Build (CLI). If `xcodebuild` complains about the developer directory,
#    point it at a full Xcode install:
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project NotchPulse.xcodeproj -scheme NotchPulse \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

# 4. Launch the built app
open ~/Library/Developer/Xcode/DerivedData/NotchPulse-*/Build/Products/Debug/NotchPulse.app
```

Or just open `NotchPulse.xcodeproj` in Xcode and hit Run.

> The `.xcodeproj` is **git-ignored** — it's a generated artifact. Run
> `xcodegen generate` after cloning.

On launch you'll see a waveform icon in the menu bar. The notch surface sits at
the top-center of your main display; hover it to expand.

---

## Event API

`POST http://127.0.0.1:7842/event` with a JSON body:

| Field      | Type           | Required | Notes                                             |
|------------|----------------|----------|---------------------------------------------------|
| `event`    | string         | yes      | `start` \| `progress` \| `update` \| `complete` \| `fail` |
| `id`       | string         | no       | Ties updates to one activity; generated if absent |
| `title`    | string         | no       | Shown in the expanded card                        |
| `source`   | string         | no       | Origin label (e.g. `Claude Code`)                 |
| `detail`   | string         | no       | Secondary line                                    |
| `progress` | number (0..1)  | no       | Drives the progress bar                           |

Behavior:

- **Valid event** → `200 {"ok":true}`.
- **Malformed JSON** → `400`, and the app never crashes.
- Wrong method → `405`; unknown path → `404`.
- `complete` activities auto-prune after ~8s; `fail` activities persist until
  cleared (hover → **Clear**, or the menu-bar **Clear All Activity**).

### Quick try

```bash
curl -s localhost:7842/event -d '{"event":"start","id":"t1","title":"Hello notch","source":"manual"}'
sleep 2
curl -s localhost:7842/event -d '{"event":"progress","id":"t1","progress":0.5,"detail":"halfway"}'
sleep 2
curl -s localhost:7842/event -d '{"event":"complete","id":"t1","detail":"done"}'
```

---

## Claude Code integration

`integrations/claude-code-hook.sh` reads a Claude Code hook payload from stdin
and forwards a compact event to the notch. It's dependency-light (jq → python3 →
regex fallback), times out fast, and **always exits 0** so it can never block a
tool call.

1. Edit `integrations/settings.example.json` — replace `/ABSOLUTE/PATH/TO` with
   the absolute path to this repo's `integrations/` directory.
2. Merge its `hooks` block into your `~/.claude/settings.json`.
3. Run NotchPulse, then use Claude Code — the pill tracks tool activity per
   session and shows a check when the session stops.

> ⚠️ Claude Code's hook input schema can change between versions. If events stop
> appearing, verify field names (`hook_event_name`, `tool_name`, `session_id`)
> against <https://docs.claude.com>.

You can override the port the hook targets with `NOTCHPULSE_PORT`.

---

## Architecture

```
Claude Code hook ─┐
build/test script ─┤ POST 127.0.0.1:7842/event ─► ActivityServer ─► ActivityStore ─► NotchView
anything else     ─┘   {event,id,title,...}       (parse JSON)      (@MainActor)     (SwiftUI)
```

| File                          | Role                                                      |
|-------------------------------|-----------------------------------------------------------|
| `NotchPulseApp.swift`         | `@main`, `MenuBarExtra`, delegate adaptor, Settings scene |
| `AppDelegate.swift`           | `.accessory` policy; owns store, server, window controller|
| `NotchState.swift`            | Hover/expansion UI state                                  |
| `ActivityStore.swift`         | `@MainActor` store; `Activity` model + `apply(event)`     |
| `ActivityServer.swift`        | `NWListener` on loopback; minimal HTTP POST parsing       |
| `NotchWindowController.swift` | Borderless `NSPanel` pinned top-center; expand animation  |
| `NotchView.swift`             | Collapsed pill + expanded card                            |

---

## Shipping checklist (commercial)

- [ ] Code signing + notarization (Developer ID), hardened runtime entitlements.
- [ ] Sparkle (or App Store) for updates — *added later; not a core dependency*.
- [ ] App icon + branding; first-run onboarding for the hook setup.
- [ ] Login-item / launch-at-startup option.
- [ ] Settings UI for port, sounds, auto-DND, lane limits.
- [ ] Crash reporting + privacy policy (note: server is loopback-only, no telemetry by default).
- [ ] License/paywall integration.

## License

Proprietary / commercial. All code is original (clean-room — no Boring Notch,
MacNotch, or other GPL/CC-BY-NC sources). © 2026 NotchPulse.
