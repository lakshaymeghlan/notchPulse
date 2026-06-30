import SwiftUI
import AppKit

/// Phase 2 — Apple's native Liquid Glass (`NSGlassEffectView`), available on
/// macOS 26+. Used as a background layer behind the notch content.
///
/// Caveat (documented by Apple-platform devs): on a `.nonactivatingPanel` the
/// effect can degrade to a plain blur or mis-tint while the window is unfocused
/// — and the notch is essentially always unfocused. So this is offered as an
/// option, with the reliable frosted faux-glass as the fallback/default.
@available(macOS 26.0, *)
struct LiquidGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 22

    func makeNSView(context: Context) -> NSGlassEffectView {
        let v = NSGlassEffectView()
        v.cornerRadius = cornerRadius
        return v
    }

    func updateNSView(_ v: NSGlassEffectView, context: Context) {
        v.cornerRadius = cornerRadius
    }
}
