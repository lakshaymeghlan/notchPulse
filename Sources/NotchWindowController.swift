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
    static let windowHeight: CGFloat = 210

    static let expandedWidth: CGFloat = 720
    static let expandedHeight: CGFloat = 196

    static let fallbackNotchWidth: CGFloat = 200
    static let fallbackNotchHeight: CGFloat = 34
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
    private let pages: PagesModel
    private var cancellables = Set<AnyCancellable>()
    private var peekTask: Task<Void, Never>?
    private var positionRetries = 0
    private var pointerMonitors: [Any] = []

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
        pages: PagesModel
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
        self.pages = pages

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
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
            .environmentObject(pages)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        container.addSubview(hosting)

        container.shapeRect = { [weak self] in self?.currentShapeRect() ?? .zero }
        panel.contentView = container

        // When expansion flips (e.g. a peek opens it under a stationary cursor),
        // re-evaluate whether the pointer is now inside the larger shape.
        notchState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] _ in self?.evaluatePointer() }
            .store(in: &cancellables)

        installPointerMonitors()

        // Peek the notch on new activity.
        store.onActivity = { [weak self] in
            guard let self else { return }
            let hasContent = self.store.hasContent
            DispatchQueue.main.async { self.peek(hasContent: hasContent) }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for m in pointerMonitors { NSEvent.removeMonitor(m) }
    }

    // MARK: - Pointer tracking / click-through

    /// We toggle `ignoresMouseEvents` based on whether the cursor is over the
    /// notch. Mouse-move monitors (global fires while another app is active,
    /// local while we are) keep it in sync without ever blocking clicks.
    private func installPointerMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluatePointer() }
        })
        if let global { pointerMonitors.append(global) }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.evaluatePointer() }
            return event
        })
        if let local { pointerMonitors.append(local) }
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
        // Capture the mouse only while over the notch; otherwise pass through.
        if panel.ignoresMouseEvents != !inside {
            panel.ignoresMouseEvents = !inside
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
        positionRetries = 0
        ensurePositioned()
    }

    /// Pin the fixed window to the top-center of the main display and resolve
    /// the notch dimensions. Retries briefly because the display subsystem can
    /// report a missing notch / bogus bounds right after launch.
    private func ensurePositioned() {
        if let screen = targetScreen {
            anchorNotch = notchSize(on: screen)
            notchState.notchSize = anchorNotch
        }

        let cg = CGDisplayBounds(CGMainDisplayID())
        if cg.width > 100 {
            let x = (cg.width - NotchMetrics.windowWidth) / 2
            let y = cg.height - NotchMetrics.windowHeight   // flush to the top
            panel.setFrame(NSRect(x: x.rounded(), y: y.rounded(),
                                  width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight),
                           display: true)
        }
        evaluatePointer()

        let sane = cg.width > 100 && anchorNotch.height > 0
        if !sane && positionRetries < 24 {
            positionRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.ensurePositioned()
            }
        }
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

        let w = expanded ? NotchMetrics.expandedWidth : collapsedW
        let h = expanded ? NotchMetrics.expandedHeight : collapsedH
        // A little vertical tolerance so the hover doesn't drop on the seam.
        let pad: CGFloat = expanded ? 0 : 4
        let x = (NotchMetrics.windowWidth - w) / 2
        let y = NotchMetrics.windowHeight - h - pad
        return NSRect(x: x, y: y, width: w, height: h + pad)
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
