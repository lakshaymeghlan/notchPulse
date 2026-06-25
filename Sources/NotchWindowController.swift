import AppKit
import SwiftUI
import Combine

/// Owns the borderless panel that floats over the notch. Handles geometry
/// (top-center, flush to the screen top), expand/collapse animation, and
/// repositioning when the screen layout changes.
@MainActor
final class NotchWindowController {

    private let panel: NotchPanel
    private let notchState: NotchState
    private let store: ActivityStore
    private var cancellables = Set<AnyCancellable>()
    private var peekTask: Task<Void, Never>?

    // Collapsed dimensions match the physical notch exactly (overlaying it);
    // these are the fallback for non-notched Macs.
    private let fallbackNotchWidth: CGFloat = 190
    private let fallbackNotchHeight: CGFloat = 32
    // Expanded surface grows wider than the notch and drops downward.
    private let expandedWidth: CGFloat = 380
    private let expandedExtraHeight: CGFloat = 172  // added below the notch strip

    init(notchState: NotchState, store: ActivityStore) {
        self.notchState = notchState
        self.store = store

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: fallbackNotchWidth, height: fallbackNotchHeight),
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
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        self.panel = panel

        let root = NotchView()
            .environmentObject(notchState)
            .environmentObject(store)
        let hosting = NSHostingView(rootView: root)
        // CRITICAL: by default NSHostingView emits Auto Layout constraints from
        // SwiftUI's intrinsic size. Those fight our manual setFrame animation on
        // hover and trip an AppKit constraint-update assertion (EXC_BREAKPOINT).
        // We drive the size ourselves, so disable hosting-view sizing entirely.
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        panel.contentView = hosting

        // Resize/reposition whenever expansion (hover or peek) flips.
        notchState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                self?.applyFrame(expanded: expanded, animated: true)
            }
            .store(in: &cancellables)

        // New/updated activity briefly peeks the notch open so it's noticeable
        // without hovering, then collapses (unless the pointer is over it).
        // Peek the notch open when activity arrives. We use the store's explicit
        // callback (fired after apply() completes) rather than observing
        // $activities, whose sink fires mid-willSet and proved unreliable here.
        store.onActivity = { [weak self] in
            guard let self else { return }
            let hasContent = self.store.hasContent
            // Hop to a fresh main run-loop turn before driving the resize: the
            // callback fires from inside apply()'s execution and the panel
            // animation is more reliable scheduled on its own turn.
            DispatchQueue.main.async {
                self.peek(hasContent: hasContent)
            }
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
    }

    func show() {
        publishNotchSize()
        applyFrame(expanded: notchState.isExpanded, animated: false)
        panel.orderFrontRegardless()
    }

    @objc private func screenParametersChanged() {
        publishNotchSize()
        applyFrame(expanded: notchState.isExpanded, animated: false)
    }

    /// Open the notch for a moment when activity arrives, then collapse if the
    /// pointer isn't over it.
    private func peek(hasContent: Bool) {
        // Don't pop open just because the last activity was pruned away.
        guard hasContent else {
            notchState.isPeeking = false
            return
        }
        notchState.isPeeking = true
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.notchState.isPeeking = false }
        }
    }

    // MARK: - Geometry

    /// The screen we live on. Prefer the screen that currently has the notch /
    /// the main screen; fall back to the first available.
    private var targetScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    /// Physical notch size of the target screen (0×0 ⇒ no notch).
    private func notchSize(on screen: NSScreen) -> CGSize {
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return .zero }
        let width = NotchGeometry.notchWidth(of: screen) ?? fallbackNotchWidth
        return CGSize(width: width, height: height)
    }

    private func publishNotchSize() {
        guard let screen = targetScreen else { return }
        notchState.notchSize = notchSize(on: screen)
    }

    private func targetFrame(expanded: Bool, on screen: NSScreen) -> NSRect {
        let full = screen.frame
        let notch = notchSize(on: screen)
        let hasNotch = notch.height > 0

        let collapsedW = hasNotch ? notch.width : fallbackNotchWidth
        let collapsedH = hasNotch ? notch.height : fallbackNotchHeight

        let width = expanded ? max(expandedWidth, collapsedW) : collapsedW
        let height = expanded ? (collapsedH + expandedExtraHeight) : collapsedH

        // Top edge flush with the very top of the display: the collapsed surface
        // overlays the hardware notch exactly; expanded grows downward from it.
        let topY = full.maxY
        let centerX = full.midX
        return NSRect(
            x: (centerX - width / 2).rounded(),
            y: (topY - height).rounded(),
            width: width,
            height: height
        )
    }

    private func applyFrame(expanded: Bool, animated: Bool) {
        guard let screen = targetScreen else { return }
        let frame = targetFrame(expanded: expanded, on: screen)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}

/// Borderless panels normally refuse key/main status; we allow key so SwiftUI
/// hit-testing (hover, buttons) works, but never steal focus from the user's app.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Notch metrics. Uses `safeAreaInsets` / `auxiliaryTopLeftArea` to detect and
/// measure the notch, with graceful fallback on non-notched Macs.
enum NotchGeometry {
    /// Returns the notch width if `screen` has one, else nil.
    static func notchWidth(of screen: NSScreen) -> CGFloat? {
        guard hasNotch(screen) else { return nil }
        // The auxiliary areas flank the notch; the gap between them is the notch.
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap > 0 { return gap }
        }
        // Fallback estimate if the auxiliary areas aren't reported.
        return 200
    }

    static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }
}
