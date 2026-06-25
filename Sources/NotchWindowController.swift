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

    // Collapsed dimensions are clamped to the real notch when one exists; these
    // are sensible defaults / fallbacks for non-notched displays.
    private let collapsedFallbackWidth: CGFloat = 200
    private let collapsedHeight: CGFloat = 32
    private let expandedWidth: CGFloat = 360
    private let expandedHeight: CGFloat = 170

    init(notchState: NotchState, store: ActivityStore) {
        self.notchState = notchState
        self.store = store

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: collapsedFallbackWidth, height: collapsedHeight),
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
        hosting.layer?.backgroundColor = .clear
        panel.contentView = hosting

        // Resize/reposition whenever hover state flips.
        notchState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                self?.applyFrame(expanded: expanded, animated: true)
            }
            .store(in: &cancellables)

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
        applyFrame(expanded: notchState.isExpanded, animated: false)
        panel.orderFrontRegardless()
    }

    @objc private func screenParametersChanged() {
        applyFrame(expanded: notchState.isExpanded, animated: false)
    }

    // MARK: - Geometry

    /// The screen we live on. Prefer the screen that currently has the notch /
    /// the main screen; fall back to the first available.
    private var targetScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    /// Width of the collapsed pill, matched to the physical notch when present.
    private func collapsedWidth(for screen: NSScreen) -> CGFloat {
        if let notchWidth = NotchGeometry.notchWidth(of: screen) {
            // A little breathing room on either side of the bezel.
            return notchWidth + 16
        }
        return collapsedFallbackWidth
    }

    private func targetFrame(expanded: Bool, on screen: NSScreen) -> NSRect {
        let width = expanded ? expandedWidth : collapsedWidth(for: screen)
        let height = expanded ? expandedHeight : collapsedHeight
        let full = screen.frame
        let centerX = full.midX
        let topY = full.maxY // flush to the very top of the display
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
