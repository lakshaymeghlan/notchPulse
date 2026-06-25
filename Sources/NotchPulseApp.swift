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
    @EnvironmentObject var widgets: WidgetSettings
    @EnvironmentObject var shelf: ShelfStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NotchPulse")
                    .font(.headline)
                Text("Pick the widgets that appear when the notch expands.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Widgets") {
                VStack(spacing: 0) {
                    ForEach(WidgetKind.allCases) { kind in
                        Toggle(isOn: widgets.binding(for: kind)) {
                            HStack(spacing: 10) {
                                Image(systemName: kind.systemImage)
                                    .frame(width: 22)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title)
                                    Text(kind.blurb)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 7)
                        if kind != WidgetKind.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Button("Clear Shelf") { shelf.clear() }
                    .disabled(shelf.items.isEmpty)
                Spacer()
                Text("Tip: drag files onto the notch to stash them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
