import SwiftUI

@main
struct NotchPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only presence. The notch UI itself lives in a borderless
        // NSPanel managed by AppDelegate; this extra is just the control surface.
        MenuBarExtra("NotchPulse", systemImage: "waveform") {
            MenuBarContent(store: appDelegate.store)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.widgetSettings)
                .environmentObject(appDelegate.shelf)
                .environmentObject(appDelegate.pages)
                .environmentObject(appDelegate.teleprompter)
                .environmentObject(appDelegate.theme)
                .environmentObject(appDelegate.pomodoro)
        }
    }
}

/// Contents of the menu-bar dropdown.
struct MenuBarContent: View {
    let store: ActivityStore

    var body: some View {
        SettingsLink {
            Text("Widgets & Settings…")
        }
        .keyboardShortcut(",")
        Text("Open settings anywhere: ⌥⌘N")
            .font(.caption)
        Button("Clear All Activity") {
            store.clearAll()
        }
        Divider()
        Button("Quit NotchPulse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            WidgetsSettings()
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            TeleprompterSettings()
                .tabItem { Label("Teleprompter", systemImage: "text.alignleft") }
        }
        .frame(width: 480, height: 560)
    }
}

/// Accent color, frosted glass, and Pomodoro durations.
struct AppearanceSettings: View {
    @EnvironmentObject var theme: ThemeModel
    @EnvironmentObject var pomo: PomodoroModel
    @AppStorage("finishSound") private var finishSound = true
    @AppStorage("finishSpeech") private var finishSpeech = false
    @AppStorage("liveEars") private var liveEars = true
    @AppStorage("glassMode") private var glassModeRaw = GlassMode.frosted.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance").font(.headline)

            Toggle(isOn: $liveEars) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Live activity beside the notch")
                    Text("Show agent status in the collapsed notch. Turn off to keep it flush so it never covers menu-bar icons.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(ThemeModel.Accent.allCases) { accent in
                        Circle()
                            .fill(accent.color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(.primary, lineWidth: theme.accent == accent ? 2 : 0))
                            .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                            .onTapGesture { theme.accent = accent }
                    }
                }
            }

            Toggle(isOn: $theme.glass) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Glass panel")
                    Text("A glassy background when expanded (collapsed stays black to blend with the notch).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if theme.glass {
                let mode = GlassMode(rawValue: glassModeRaw) ?? .frosted
                Picker("Glass style", selection: $glassModeRaw) {
                    ForEach(GlassMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.menu)
                .padding(.leading, 4)
                Text(mode.blurb).font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                if mode == .live {
                    Button("Grant Screen Recording access") { CGRequestScreenCaptureAccess() }
                        .font(.caption).padding(.leading, 4)
                }
            }

            Divider()

            Text("When an agent finishes").font(.subheadline).foregroundStyle(.secondary)
            Toggle("Play a sound", isOn: $finishSound).toggleStyle(.switch)
            Toggle("Speak it out loud", isOn: $finishSpeech).toggleStyle(.switch)

            Divider()

            Text("Pomodoro").font(.subheadline).foregroundStyle(.secondary)
            Stepper(value: $pomo.workMinutes, in: 5...90, step: 5) {
                Text("Focus: \(pomo.workMinutes) min")
            }
            Stepper(value: $pomo.breakMinutes, in: 1...30, step: 1) {
                Text("Break: \(pomo.breakMinutes) min")
            }

            Spacer()
        }
        .padding(20)
    }
}

/// Edit the teleprompter script, scroll speed, and target duration.
struct TeleprompterSettings: View {
    @EnvironmentObject var prompter: TeleprompterModel
    @State private var minutes = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teleprompter script").font(.headline)
            Text("Paste or type your full script — it scrolls in the Teleprompter widget (Studio page).")
                .font(.subheadline).foregroundStyle(.secondary)

            TextEditor(text: $prompter.script)
                .font(.system(size: 13))
                .frame(minHeight: 240)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))

            HStack {
                Button("Clear") { prompter.script = "" }
                Spacer()
                Text("\(prompter.script.split(whereSeparator: { $0.isWhitespace }).count) words")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            // Text size.
            HStack {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                Slider(value: $prompter.fontSize, in: 10...40)
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
                Text("\(Int(prompter.fontSize)) pt").monospacedDigit().frame(width: 64, alignment: .trailing)
            }

            // Manual speed.
            HStack {
                Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                Slider(value: $prompter.speed, in: 8...200)
                Image(systemName: "hare.fill").foregroundStyle(.secondary)
                Text("\(Int(prompter.speed)) pt/s").monospacedDigit().frame(width: 64, alignment: .trailing)
            }

            // Auto-speed: make the whole script take a set time.
            HStack(spacing: 10) {
                Text("Make it last").foregroundStyle(.secondary)
                Stepper(value: $minutes, in: 0.25...30, step: 0.25) {
                    Text(TeleprompterModel.clock(minutes * 60)).monospacedDigit()
                }
                .fixedSize()
                Button("Set speed") { prompter.setDuration(minutes * 60) }
                Spacer()
                Text("Est. total \(TeleprompterModel.clock(prompter.totalSeconds))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .help("Sets the scroll speed so the script finishes in the chosen time (open the widget once so it can measure the text).")
        }
        .padding(20)
    }
}

/// Per-page widget editor: pick a page, then check/uncheck and drag-reorder the
/// widgets that appear on it. This is the "edit / add any widget" surface.
struct WidgetsSettings: View {
    @EnvironmentObject var pages: PagesModel
    @EnvironmentObject var shelf: ShelfStore
    @State private var pageIndex = 0

    private var page: NotchPage { pages.pages[min(pageIndex, pages.pages.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit widgets").font(.headline)
                Text("Choose which widgets show on each page. Drag to reorder; they appear left-to-right.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Picker("Page", selection: $pageIndex) {
                ForEach(Array(pages.pages.enumerated()), id: \.element.id) { i, p in
                    Label(p.title, systemImage: p.icon).tag(i)
                }
            }
            .pickerStyle(.segmented)

            // Widgets currently on this page — reorderable & removable.
            List {
                Section("On this page") {
                    ForEach(page.widgets, id: \.self) { kind in
                        HStack(spacing: 10) {
                            Image(systemName: kind.systemImage).frame(width: 20).foregroundStyle(.tint)
                            Text(kind.title)
                            Spacer()
                            Button {
                                pages.setWidget(kind, onPage: page.id, included: false)
                            } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { pages.moveWidgets(onPage: page.id, from: $0, to: $1) }

                    if page.widgets.isEmpty {
                        Text("No widgets yet — add some below.").foregroundStyle(.secondary).font(.caption)
                    }
                }

                Section("Available widgets") {
                    ForEach(WidgetKind.allCases.filter { !page.widgets.contains($0) }) { kind in
                        Button {
                            pages.setWidget(kind, onPage: page.id, included: true)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: kind.systemImage).frame(width: 20).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title).foregroundStyle(.primary)
                                    Text(kind.blurb).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 280)

            HStack {
                Button("Reset Pages") { pages.resetToDefaults(); pageIndex = 0 }
                Button("Clear Shelf") { shelf.clear() }.disabled(shelf.items.isEmpty)
                Spacer()
                Text("Tip: hover the notch to open it.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460, height: 520)
    }
}
