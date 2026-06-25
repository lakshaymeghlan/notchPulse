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
        }
    }
}

/// Contents of the menu-bar dropdown.
struct MenuBarContent: View {
    let store: ActivityStore

    var body: some View {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("NotchPulse")
                .font(.headline)
            Text("Live-activity surface for your MacBook notch.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360, height: 120)
    }
}
