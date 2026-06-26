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

    /// Derived: expanded when hovered, peeking, or pinned.
    @Published private(set) var isExpanded: Bool = false

    /// Physical notch size of the current screen (height 0 ⇒ no notch).
    @Published var notchSize: CGSize = .init(width: 0, height: 0)

    private func recompute() {
        let next = isHovering || isPeeking || isPinned
        if next != isExpanded { isExpanded = next }
    }
}
