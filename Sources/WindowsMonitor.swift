import AppKit
import CoreGraphics
import Combine

/// Lists on-screen windows via CoreGraphics. Window titles require Screen
/// Recording permission; without it we still show the owning app + icon.
@MainActor
final class WindowsMonitor: ObservableObject {
    struct Win: Identifiable {
        let id: CGWindowID
        let title: String
        let appName: String
        let ownerPID: pid_t
        let icon: NSImage?
    }

    @Published private(set) var windows: [Win] = []
    /// True if we can read window titles (Screen Recording granted).
    @Published private(set) var canReadTitles: Bool = false

    private var timer: Timer?

    init() {
        canReadTitles = CGPreflightScreenCaptureAccess()
        refresh()
    }

    deinit { timer?.invalidate() }

    func startPolling() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 1
        timer = t
        refresh()
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func requestTitleAccess() {
        // Prompts for Screen Recording on first call.
        _ = CGRequestScreenCaptureAccess()
        canReadTitles = CGPreflightScreenCaptureAccess()
        refresh()
    }

    func refresh() {
        let opts = CGWindowListOption(arrayLiteral: [.optionOnScreenOnly, .excludeDesktopElements])
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var result: [Win] = []
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue } // normal windows
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != myPID else { continue }
            let appName = (info[kCGWindowOwnerName as String] as? String) ?? "App"
            let title = (info[kCGWindowName as String] as? String) ?? ""
            // Skip tiny utility windows.
            if let b = info[kCGWindowBounds as String] as? [String: CGFloat],
               (b["Width"] ?? 0) < 80 || (b["Height"] ?? 0) < 60 { continue }
            let id = (info[kCGWindowNumber as String] as? CGWindowID) ?? 0
            let icon = NSRunningApplication(processIdentifier: pid)?.icon
            result.append(Win(id: id,
                              title: title.isEmpty ? appName : title,
                              appName: appName,
                              ownerPID: pid,
                              icon: icon))
        }
        windows = result
    }

    func activate(_ win: Win) {
        let app = NSRunningApplication(processIdentifier: win.ownerPID)
        if let url = app?.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        } else {
            app?.activate(options: [.activateAllWindows])
        }
    }
}
