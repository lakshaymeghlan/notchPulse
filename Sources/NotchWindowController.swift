import AppKit
import SwiftUI
import Combine

/// Fixed geometry for the notch surface. The window never resizes — only the
/// SwiftUI content animates inside it — which is what keeps expand/collapse
/// smooth and glitch-free.
enum NotchMetrics {
    // The host window is a fixed rectangle pinned to the top-center of the
    // display. It must be at least as large as the expanded surface.
    static let windowWidth: CGFloat = 760
    static let windowHeight: CGFloat = 280   // room for the floating tab row below

    static let expandedWidth: CGFloat = 720
    static let expandedHeight: CGFloat = 196

    // Floating round tab buttons beneath the panel (macnotch-style).
    static let tabBarGap: CGFloat = 14
    static let tabButtonSize: CGFloat = 42

    static let fallbackNotchWidth: CGFloat = 200
    static let fallbackNotchHeight: CGFloat = 34

    /// Total interactive height when expanded (panel + gap + tab row).
    static var expandedInteractiveHeight: CGFloat { expandedHeight + tabBarGap + tabButtonSize }
}

/// Owns the borderless panel hosting the notch UI. The window is a fixed size;
/// expansion is animated entirely in SwiftUI. Mouse events pass through
/// everywhere except the current notch shape (handled by NotchContainerView).
@MainActor
final class NotchWindowController {

    private let panel: NotchPanel
    private let container: NotchContainerView
    private let notchState: NotchState
    private let store: ActivityStore
    private let widgetSettings: WidgetSettings
    private let battery: BatteryMonitor
    private let shelf: ShelfStore
    private let openApps: OpenAppsMonitor
    private let windows: WindowsMonitor
    private let camera: CameraController
    private let calendar: CalendarMonitor
    private let music: NowPlayingMonitor
    private let teleprompter: TeleprompterModel
    private let stats: SystemStatsMonitor
    private let pomodoro: PomodoroModel
    private let theme: ThemeModel
    private let ask: AskModel
    private let clipboard: ClipboardMonitor
    private let approvals: ApprovalStore
    private let todo: TodoModel
    private let notes: NotesModel
    private let shortcuts: ShortcutsModel
    private let bluetooth: BluetoothMonitor
    private let pages: PagesModel
    private let userActivity: UserActivityMonitor
    private var cancellables = Set<AnyCancellable>()
    private var peekTask: Task<Void, Never>?
    private var positionRetries = 0
    private var pointerMonitors: [Any] = []
    private let feedback = FinishFeedback()

    init(
        notchState: NotchState,
        store: ActivityStore,
        widgetSettings: WidgetSettings,
        battery: BatteryMonitor,
        shelf: ShelfStore,
        openApps: OpenAppsMonitor,
        windows: WindowsMonitor,
        camera: CameraController,
        calendar: CalendarMonitor,
        music: NowPlayingMonitor,
        teleprompter: TeleprompterModel,
        stats: SystemStatsMonitor,
        pomodoro: PomodoroModel,
        theme: ThemeModel,
        ask: AskModel,
        clipboard: ClipboardMonitor,
        approvals: ApprovalStore,
        todo: TodoModel,
        notes: NotesModel,
        shortcuts: ShortcutsModel,
        bluetooth: BluetoothMonitor,
        pages: PagesModel,
        userActivity: UserActivityMonitor
    ) {
        self.notchState = notchState
        self.store = store
        self.widgetSettings = widgetSettings
        self.battery = battery
        self.shelf = shelf
        self.openApps = openApps
        self.windows = windows
        self.camera = camera
        self.calendar = calendar
        self.music = music
        self.teleprompter = teleprompter
        self.stats = stats
        self.pomodoro = pomodoro
        self.theme = theme
        self.ask = ask
        self.clipboard = clipboard
        self.approvals = approvals
        self.todo = todo
        self.notes = notes
        self.shortcuts = shortcuts
        self.bluetooth = bluetooth
        self.pages = pages
        self.userActivity = userActivity

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Shielding-window level floats above other apps' full-screen spaces, so
        // the notch stays visible when you switch to a full-screen app's desktop.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        // Start fully click-through. We only capture the mouse while the cursor
        // is actually over the notch shape (see installPointerMonitors), so the
        // big transparent window never blocks clicks to apps beneath it.
        panel.ignoresMouseEvents = true
        self.panel = panel

        let container = NotchContainerView(frame: panel.contentLayoutRect)
        container.autoresizingMask = [.width, .height]
        // Keep the whole layer tree non-opaque so .behindWindow blur isn't blocked.
        container.wantsLayer = true
        container.layer?.isOpaque = false
        container.layer?.backgroundColor = .clear
        self.container = container

        let root = NotchView()
            .environmentObject(notchState)
            .environmentObject(store)
            .environmentObject(widgetSettings)
            .environmentObject(battery)
            .environmentObject(shelf)
            .environmentObject(openApps)
            .environmentObject(windows)
            .environmentObject(camera)
            .environmentObject(calendar)
            .environmentObject(music)
            .environmentObject(teleprompter)
            .environmentObject(stats)
            .environmentObject(pomodoro)
            .environmentObject(theme)
            .environmentObject(ask)
            .environmentObject(clipboard)
            .environmentObject(approvals)
            .environmentObject(todo)
            .environmentObject(notes)
            .environmentObject(shortcuts)
            .environmentObject(bluetooth)
            .environmentObject(pages)
            .environmentObject(userActivity)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        hosting.layer?.backgroundColor = .clear
        container.addSubview(hosting)

        container.shapeRect = { [weak self] in self?.currentShapeRect() ?? .zero }
        panel.contentView = container

        // When expansion flips (e.g. a peek opens it under a stationary cursor),
        // re-evaluate whether the pointer is now inside the larger shape.
        notchState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                if expanded { Haptics.pop() }
                self?.evaluatePointer()
            }
            .store(in: &cancellables)

        installPointerMonitors()

        // Peek only on meaningful edges — when an agent STARTS (idle→active) or
        // FINISHES (→success/failure) — not on every progress update, which made
        // the notch pop open repeatedly during a session.
        store.onActivity = { [weak self] in
            guard let self else { return }
            let prev = self.lastSummary
            let summary = self.store.summary
            let shouldPeek = self.peekWorthy(from: prev, to: summary)
            self.lastSummary = summary

            // Finish edge → celebrate + sound/speech.
            if self.isFinished(summary) && !self.isFinished(prev) {
                let success: Bool = { if case .success = summary { return true } else { return false } }()
                let latest = self.store.activities.first
                self.notchState.celebrate(success ? .success : .failure)
                self.feedback.finished(success: success, title: latest?.title, source: latest?.source)
            }

            guard shouldPeek else { return }
            DispatchQueue.main.async { self.peek(hasContent: self.store.hasContent) }
        }

        // An agent is waiting on Approve/Deny → force the notch open until decided.
        approvals.onChange = { [weak self] in
            guard let self else { return }
            let waiting = !self.approvals.pending.isEmpty
            DispatchQueue.main.async {
                if waiting { Haptics.pop() }
                self.notchState.forceOpen = waiting
                self.evaluatePointer()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // Keep the panel present across Space switches / window drags so it
        // doesn't blink out and reappear.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        panel.orderFrontRegardless()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for m in pointerMonitors { NSEvent.removeMonitor(m) }
    }

    // MARK: - Pointer tracking / click-through

    /// We toggle `ignoresMouseEvents` based on whether the cursor is over the
    /// notch. Mouse-move monitors (global fires while another app is active,
    /// local while we are) keep it in sync without ever blocking clicks.
    private func installPointerMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.maybeFollowCursor()
                self?.evaluatePointer()
            }
        })
        if let global { pointerMonitors.append(global) }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated {
                self?.maybeFollowCursor()
                self?.evaluatePointer()
            }
            return event
        })
        if let local { pointerMonitors.append(local) }
    }

    /// Stable identifier for a screen (NSScreen instances aren't identity-stable).
    private func displayID(_ screen: NSScreen?) -> CGDirectDisplayID {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    /// Which display the cursor is currently on.
    private func screenUnderCursor() -> NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    private var followActiveDisplay: Bool {
        UserDefaults.standard.object(forKey: "followActiveDisplay") == nil
            ? true : UserDefaults.standard.bool(forKey: "followActiveDisplay")
    }

    /// Move the notch to the display the cursor just entered (only when it
    /// actually changes screens, so it never thrashes on ordinary movement).
    private func maybeFollowCursor() {
        guard followActiveDisplay, let s = screenUnderCursor() else { return }
        let id = displayID(s)
        let currentID = activeScreenID ?? displayID(targetScreen)
        guard id != 0, id != currentID else { return }
        NSLog("[NotchPulse] follow → display \(id) (was \(currentID))")
        activeScreenID = id
        positionRetries = 0
        ensurePositioned()
    }

    /// The current notch shape rect in screen coordinates (bottom-left origin).
    private func screenShapeRect() -> NSRect {
        let local = currentShapeRect()
        let origin = panel.frame.origin
        return NSRect(x: origin.x + local.minX, y: origin.y + local.minY,
                      width: local.width, height: local.height)
    }

    private func evaluatePointer() {
        let inside = screenShapeRect().contains(NSEvent.mouseLocation)
        // While pinned or editing the layout, the panel stays interactive so you
        // can type / drag even if the cursor briefly leaves it.
        let interactive = inside || notchState.isPinned || notchState.editingLayout
        if panel.ignoresMouseEvents != !interactive {
            panel.ignoresMouseEvents = !interactive
        }
        if notchState.isHovering != inside {
            notchState.isHovering = inside
        }
    }

    func show() {
        positionRetries = 0
        ensurePositioned()
        panel.orderFrontRegardless()
    }

    @objc private func screenParametersChanged() {
        // Drop a stale active screen (e.g. a display was unplugged).
        if let id = activeScreenID, !NSScreen.screens.contains(where: { displayID($0) == id }) {
            activeScreenID = nil
        }
        positionRetries = 0
        ensurePositioned()
    }

    /// The display we should currently sit on: the one the cursor last moved to
    /// (if "follow active display" is on), else the built-in notched screen.
    private var positioningScreen: NSScreen? {
        if let id = activeScreenID, let s = NSScreen.screens.first(where: { displayID($0) == id }) {
            return s
        }
        return targetScreen ?? NSScreen.main
    }

    /// Pin the fixed window to the top-center of the active display and resolve
    /// the notch dimensions (zero on a non-notched external → floating pill).
    /// Retries briefly because the display subsystem can report bogus bounds
    /// right after launch.
    private func ensurePositioned() {
        guard let screen = positioningScreen else { return }
        anchorNotch = notchSize(on: screen)
        notchState.notchSize = anchorNotch

        let f = screen.frame   // global Cocoa coords (bottom-left origin)
        if f.width > 100 {
            let x = f.midX - NotchMetrics.windowWidth / 2
            let y = f.maxY - NotchMetrics.windowHeight   // flush to that screen's top
            let target = NSRect(x: x.rounded(), y: y.rounded(),
                                width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight)
            // Only move when it actually changed — avoids a re-frame flicker.
            if panel.frame != target { panel.setFrame(target, display: false) }
            // Always re-assert visibility so it never blinks out during a
            // window drag / display or Space change.
            panel.orderFrontRegardless()
        }
        evaluatePointer()

        // On the built-in we wait until the notch is actually measured; on an
        // external display there's no notch to wait for.
        let notched = screen.safeAreaInsets.top > 0
        let sane = f.width > 100 && (!notched || anchorNotch.height > 0)
        if !sane && positionRetries < 24 {
            positionRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.ensurePositioned()
            }
        }
    }

    private var lastSummary: ActivityStore.Summary = .idle

    private func isFinished(_ s: ActivityStore.Summary) -> Bool {
        if case .success = s { return true }
        if case .failure = s { return true }
        return false
    }

    /// Whether a summary transition is worth peeking the notch open.
    private func peekWorthy(from old: ActivityStore.Summary, to new: ActivityStore.Summary) -> Bool {
        if case .idle = old, new != .idle { return true }       // agent started
        if isFinished(new) && !isFinished(old) { return true }  // agent finished
        return false
    }

    private func peek(hasContent: Bool) {
        guard hasContent else {
            notchState.isPeeking = false
            return
        }
        notchState.isPeeking = true
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.notchState.isPeeking = false }
        }
    }

    // MARK: - Geometry

    private var anchorNotch: CGSize = .zero
    /// The display the notch is following the cursor onto (nil = built-in notch).
    private var activeScreenID: CGDirectDisplayID?

    private var targetScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func notchSize(on screen: NSScreen) -> CGSize {
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return .zero }
        let width = NotchGeometry.notchWidth(of: screen) ?? NotchMetrics.fallbackNotchWidth
        return CGSize(width: width, height: height)
    }

    /// The interactive notch rect within the container (bottom-left origin),
    /// matching whatever SwiftUI is currently drawing.
    private func currentShapeRect() -> NSRect {
        let expanded = notchState.isExpanded
        let hasNotch = anchorNotch.height > 0
        let notchW = hasNotch ? anchorNotch.width : NotchMetrics.fallbackNotchWidth
        let collapsedH = hasNotch ? anchorNotch.height : NotchMetrics.fallbackNotchHeight
        let active = store.summary != .idle
        let collapsedW = NotchLayout.collapsedWidth(notchWidth: notchW, active: active)

        // When collapsed, pad the hit zone (wider + taller) so the cursor
        // reliably catches it on the first approach.
        let hPad: CGFloat = expanded ? 0 : 14
        let vPad: CGFloat = expanded ? 0 : 12
        let w = (expanded ? NotchMetrics.expandedWidth : collapsedW) + hPad
        // When expanded, extend the hit region down to cover the floating tab row.
        let h = (expanded ? NotchMetrics.expandedInteractiveHeight : collapsedH) + vPad
        let x = (NotchMetrics.windowWidth - w) / 2
        let y = NotchMetrics.windowHeight - h
        return NSRect(x: x, y: y, width: w, height: h)
    }
}

/// Hosts the SwiftUI view. Click-through is handled by the controller toggling
/// the window's `ignoresMouseEvents`; this just refines hit-testing to the
/// actual notch shape so the transparent corners never eat a click.
final class NotchContainerView: NSView {
    var shapeRect: () -> NSRect = { .zero }

    override var isFlipped: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard shapeRect().contains(local) else { return nil }
        return super.hitTest(point)
    }
}

/// Borderless panels normally refuse key status; allow it so SwiftUI buttons and
/// drops work, but never steal focus from the user's app.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Notch metrics. Uses `safeAreaInsets` / `auxiliaryTopLeftArea` to detect and
/// measure the notch, with graceful fallback on non-notched Macs.
enum NotchGeometry {
    static func notchWidth(of screen: NSScreen) -> CGFloat? {
        guard hasNotch(screen) else { return nil }
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap > 0 { return gap }
        }
        return 200
    }

    static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }
}
