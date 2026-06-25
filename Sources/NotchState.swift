import SwiftUI
import Combine

/// Transient UI state for the notch surface — currently just hover/expansion.
/// Kept separate from ActivityStore so view-only state never triggers data work.
@MainActor
final class NotchState: ObservableObject {
    /// True while the pointer is over the notch surface (drives expansion).
    @Published var isExpanded: Bool = false
}
