import AppKit
import Combine
import ApplicationServices

/// Watches what *you* are doing so the mascot can mirror it: which app is in the
/// foreground, and how fast you're typing right now. Foreground-app tracking
/// needs no permission; the typing pulse needs Accessibility (it degrades
/// silently to "no typing" until granted).
///
/// Privacy: we only ever record keystroke *timing* — never key codes, never
/// characters. Nothing is stored or sent anywhere; the whole thing is local.
@MainActor
final class UserActivityMonitor: ObservableObject {
    enum Context: Equatable { case coding, terminal, browsing, writing, design, comms, other }

    @Published private(set) var appName: String = ""
    @Published private(set) var context: Context = .other
    @Published private(set) var isTyping: Bool = false
    @Published private(set) var typingIntensity: Double = 0   // 0…1, decays when you pause
    /// True when we can't see keystrokes because Accessibility isn't granted.
    @Published private(set) var needsInputAccess: Bool = false

    /// You're "working" when you're in a code/terminal app or actively typing.
    var isWorking: Bool { context == .coding || context == .terminal || isTyping }

    /// Nod depth for the mascot: your live typing pace, or a gentle baseline
    /// when you're parked in a code editor but not actively typing (reading).
    var mascotIntensity: Double {
        isTyping ? typingIntensity : (isWorking ? 0.2 : 0)
    }

    private var keyMonitor: Any?
    private var stamps: [TimeInterval] = []          // recent keystroke times (uptime)
    private var decay: Timer?

    // Bundle-id fragments → context. Matched case-insensitively as substrings so
    // variants (Insiders, EAP builds, forks) still resolve.
    private static let coding = ["com.apple.dt.xcode", "com.microsoft.vscode", "com.todesktop", // Cursor
                                 "dev.zed.zed", "com.sublimetext", "com.panic.nova", "com.jetbrains",
                                 "com.exafunction.windsurf", "com.visualstudio.code"]
    private static let terminal = ["com.apple.terminal", "com.googlecode.iterm2", "dev.warp.warp",
                                   "io.alacritty", "net.kovidgoyal.kitty", "com.github.wez.wezterm"]
    private static let browsing = ["com.apple.safari", "com.google.chrome", "company.thebrowser",
                                   "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.browser"]
    private static let writing = ["com.apple.notes", "notion.id", "md.obsidian", "com.microsoft.word",
                                  "com.apple.iwork.pages", "com.literatureandlatte"]
    private static let design = ["com.figma", "com.bohemiancoding.sketch3", "com.adobe.photoshop",
                                 "com.adobe.illustrator", "com.seriflabs"]
    private static let comms = ["com.tinyspeck.slackmacgap", "com.hnc.discord", "com.apple.mail",
                                "us.zoom.xos", "com.microsoft.teams", "com.readdle.spark"]

    func start() {
        updateFrontmost(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        installKeyMonitor()

        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.recomputeTyping() }
        }
        t.tolerance = 0.1
        decay = t
    }

    func stop() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        decay?.invalidate(); decay = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateFrontmost(app)
    }

    private func updateFrontmost(_ app: NSRunningApplication?) {
        let name = app?.localizedName ?? ""
        let ctx = Self.categorize(bundleID: app?.bundleIdentifier, name: name)
        if appName != name { appName = name }
        if context != ctx { context = ctx }
    }

    static func categorize(bundleID: String?, name: String) -> Context {
        let id = (bundleID ?? "").lowercased()
        let n = name.lowercased()
        func hits(_ list: [String]) -> Bool { list.contains { id.contains($0) } }
        if hits(coding) || n.contains("cursor") || n.contains("intellij") || n.contains("pycharm")
            || n.contains("webstorm") || n.contains("goland") || n.contains("android studio") { return .coding }
        if hits(terminal) || n.contains("terminal") || n.contains("iterm") || n.contains("warp") { return .terminal }
        if hits(browsing) { return .browsing }
        if hits(writing)  { return .writing }
        if hits(design)   { return .design }
        if hits(comms)    { return .comms }
        return .other
    }

    private func installKeyMonitor() {
        needsInputAccess = !AXIsProcessTrusted()
        // Global key monitors only fire once the app is trusted for Accessibility;
        // if it isn't, this simply never calls back (no crash, no error).
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.registerKey() }
        }
    }

    private func registerKey() {
        if needsInputAccess { needsInputAccess = false }   // we're clearly getting events now
        stamps.append(ProcessInfo.processInfo.systemUptime)
        recomputeTyping()
    }

    /// Map keystrokes-in-the-last-1.5s to a 0…1 intensity; ~8 keys = full tilt.
    private func recomputeTyping() {
        let now = ProcessInfo.processInfo.systemUptime
        stamps.removeAll { now - $0 > 1.5 }
        let intensity = min(1, Double(stamps.count) / 8.0)
        let typing = !stamps.isEmpty
        if typingIntensity != intensity { typingIntensity = intensity }
        if isTyping != typing { isTyping = typing }
    }

    /// Open System Settings → Privacy → Accessibility so the user can grant the
    /// permission the typing-mirror needs.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
