import SwiftUI
import AppKit

/// Appearance: accent color + optional frosted-glass panel. Persisted.
@MainActor
final class ThemeModel: ObservableObject {
    enum Accent: String, CaseIterable, Identifiable, Codable {
        case green, blue, purple, pink, orange, teal, white
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .green: return .green
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .orange: return .orange
            case .teal: return .teal
            case .white: return .white
            }
        }
        var title: String { rawValue.capitalized }
    }

    @Published var accent: Accent { didSet { UserDefaults.standard.set(accent.rawValue, forKey: "theme.accent") } }
    /// Frosted-glass panel background when expanded (collapsed stays pitch black).
    @Published var glass: Bool { didSet { UserDefaults.standard.set(glass, forKey: "theme.glass") } }

    init() {
        accent = Accent(rawValue: UserDefaults.standard.string(forKey: "theme.accent") ?? "green") ?? .green
        glass = UserDefaults.standard.bool(forKey: "theme.glass")
    }
}

/// A dark frosted-glass background (NSVisualEffectView).
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
