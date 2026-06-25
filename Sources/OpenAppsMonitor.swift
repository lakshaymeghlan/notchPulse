import AppKit
import Combine

/// Tracks the regular (Dock-visible) running apps — the "what's open" widget.
@MainActor
final class OpenAppsMonitor: ObservableObject {
    struct App: Identifiable, Equatable {
        let id: pid_t
        let name: String
        let icon: NSImage?
        let isActive: Bool
    }

    @Published private(set) var apps: [App] = []

    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append(token)
        }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for o in observers { nc.removeObserver(o) }
    }

    func refresh() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
        apps = running.map {
            App(id: $0.processIdentifier,
                name: $0.localizedName ?? "App",
                icon: $0.icon,
                isActive: $0.isActive)
        }
    }
}
