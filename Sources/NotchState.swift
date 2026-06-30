import SwiftUI
import Combine

/// Transient UI state for the notch surface: hover, a short auto-"peek" when new
/// activity arrives, and the measured physical-notch metrics so the view can
/// keep its content clear of the camera.
@MainActor
final class NotchState: ObservableObject {

    /// True while the pointer is over the surface.
    @Published var isHovering: Bool = false { didSet { recompute() } }

    /// True for a few seconds after new activity, so events are noticeable even
    /// without hovering (Dynamic-Island-style peek).
    @Published var isPeeking: Bool = false { didSet { recompute() } }

    /// User pinned it open (stays open regardless of hover — for typing/reading).
    @Published var isPinned: Bool = false { didSet { recompute() } }

    /// Force-open (e.g. while an agent is waiting for an Approve/Deny decision).
    @Published var forceOpen: Bool = false { didSet { recompute() } }

    /// Layout edit mode — drag to reorder / resize widgets right in the notch.
    /// Keeps the panel open and makes widget content non-interactive.
    @Published var editingLayout: Bool = false { didSet { recompute() } }

    /// Derived: expanded when hovered, peeking, or pinned.
    @Published private(set) var isExpanded: Bool = false

    /// Physical notch size of the current screen (height 0 ⇒ no notch).
    @Published var notchSize: CGSize = .init(width: 0, height: 0)

    /// A momentary celebration when an agent finishes (drives the overlay).
    enum Celebration: Equatable { case none, success, failure }
    @Published private(set) var celebration: Celebration = .none
    private var celebrateTask: Task<Void, Never>?

    func celebrate(_ kind: Celebration) {
        celebration = kind
        celebrateTask?.cancel()
        celebrateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.celebration = .none }
        }
    }

    private func recompute() {
        let next = isHovering || isPeeking || isPinned || forceOpen || editingLayout
        if next != isExpanded { isExpanded = next }
    }
}
