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

/// Which technique renders the glass surface when glass mode is ON.
enum GlassMode: String, CaseIterable, Identifiable {
    case frosted   // Phase 1 — faux glass, reliable everywhere, zero permission
    case liquid    // Phase 2 — Apple NSGlassEffectView (macOS 26+), else frosted
    case live      // Phase 3 — ScreenCaptureKit real blur of what's behind (opt-in)

    var id: String { rawValue }
    var title: String {
        switch self {
        case .frosted: return "Frosted (recommended)"
        case .liquid: return "Liquid Glass (macOS 26)"
        case .live: return "Live Glass (screen capture)"
        }
    }
    var blurb: String {
        switch self {
        case .frosted: return "Reliable dark glass. No permissions, no battery cost."
        case .liquid: return "Apple's native material on macOS 26. May fall back while unfocused."
        case .live: return "Truly blurs what's behind the notch. Needs Screen Recording permission."
        }
    }
}

/// Tunables for the faux-glass surface (Phase 1). Tweak here.
enum GlassStyle {
    static let topTint = Color(white: 0.18)      // charcoal
    static let bottomTint = Color(white: 0.06)   // near-black
    static let rimTop = Color.white.opacity(0.14)
    static let rimBottom = Color.white.opacity(0.02)
    static let hairline = Color.white.opacity(0.05)
    static let grainOpacity: Double = 0.035
}

/// A small, cached grayscale-noise tile used to give the faux glass a subtle
/// grain so it reads as a real material rather than a flat gradient.
struct NoiseTexture: View {
    var body: some View {
        Image(nsImage: NoiseTexture.tile)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
    }

    static let tile: NSImage = make(120)

    private static func make(_ side: Int) -> NSImage {
        let bytesPerRow = side * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * side)
        for i in stride(from: 0, to: data.count, by: 4) {
            let v = UInt8.random(in: 0...255)
            data[i] = v; data[i + 1] = v; data[i + 2] = v; data[i + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = ctx.makeImage() else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }
}

/// Legacy behind-window blur — kept for reference but NOT used: the WindowServer
/// doesn't reliably feed a backdrop to a non-activating .statusBar overlay, so it
/// renders flat. We use the faux-glass surface instead (see NotchView).
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
