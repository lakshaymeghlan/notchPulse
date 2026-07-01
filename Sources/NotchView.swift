import SwiftUI
import AppKit

/// Subtle trackpad haptics for a premium feel.
enum Haptics {
    static func pop() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
}

/// The notch silhouette: square top flush with the bezel, rounded bottom.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topCornerRadius, rect.height / 2))
        let br = max(0, min(bottomCornerRadius, rect.height - tr, rect.width / 2))
        // Cubic control factor for a smooth, Apple-style continuous corner
        // (rather than a slightly pinched quadratic arc).
        let k: CGFloat = 0.5523
        var p = Path()

        // Top-left fillet (curves inward from the bezel).
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                   control1: CGPoint(x: rect.minX + tr * k, y: rect.minY),
                   control2: CGPoint(x: rect.minX + tr, y: rect.minY + tr * (1 - k)))

        // Left edge down to the bottom-left squircle corner.
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                   control1: CGPoint(x: rect.minX + tr, y: rect.maxY - br * (1 - k)),
                   control2: CGPoint(x: rect.minX + tr + br * (1 - k), y: rect.maxY))

        // Bottom edge to the bottom-right squircle corner.
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                   control1: CGPoint(x: rect.maxX - tr - br * (1 - k), y: rect.maxY),
                   control2: CGPoint(x: rect.maxX - tr, y: rect.maxY - br * (1 - k)))

        // Right edge up to the top-right fillet.
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                   control1: CGPoint(x: rect.maxX - tr, y: rect.minY + tr * (1 - k)),
                   control2: CGPoint(x: rect.maxX - tr * k, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Shared sizing so the view and the window controller agree on the shape rect.
enum NotchLayout {
    /// Whether the live-activity "ears" beside the notch are drawn (default on).
    /// Off ⇒ the collapsed surface stays flush to the physical notch so it never
    /// covers menu-bar icons. Toggled in Settings → Appearance.
    static var showsEars: Bool {
        UserDefaults.standard.object(forKey: "liveEars") == nil
            ? true : UserDefaults.standard.bool(forKey: "liveEars")
    }

    /// Dynamic collapsed width: two EQUAL halves (sized to the wider label) on
    /// each side of the camera, so the pill is symmetric and the labels read as
    /// centered/balanced — not shoved to one side.
    static func collapsedWidth(notchWidth: CGFloat, active: Bool) -> CGFloat {
        guard active, showsEars else { return notchWidth }
        return notchWidth + 90   // room for a small pulse dot beside the notch
    }
}

/// Measures the live-activity labels so the collapsed pill can size itself.
enum LiveActivity {
    static let gap: CGFloat = 4        // inner gap (text → camera)
    static let outer: CGFloat = 24     // so each label keeps ≥14pt inset, centered
    static let maxLabel: CGFloat = 150 // cap; longer labels truncate with an ellipsis
    static let weight: NSFont.Weight = .medium   // same weight for both labels

    static func labels(summary: ActivityStore.Summary, source: String?) -> (left: String, right: String) {
        let left: String
        if case .running(let n) = summary, n > 1 { left = "\(n) agents" }
        else { left = source ?? "Agent" }
        let right: String
        switch summary {
        case .running: right = "running"
        case .success: right = "done"
        case .failure: right = "failed"
        case .idle: right = ""
        }
        return (left, right)
    }

    /// Width of one side: the wider label + its gap + outer padding (so both
    /// halves are equal and the camera gap is centered). Capped for long names.
    static func halfWidth(left: String, right: String) -> CGFloat {
        let w = min(max(measure(left, weight: weight), measure(right, weight: weight)), maxLabel)
        return w + gap + outer
    }

    /// Measure with the SAME font we render with — system 11pt, rounded design.
    /// (Rounded is wider than the default system font; measuring with the wrong
    /// one under-sizes the pill and clips the text.)
    static func measure(_ s: String, weight: NSFont.Weight) -> CGFloat {
        guard !s.isEmpty else { return 0 }
        let base = NSFont.systemFont(ofSize: 11, weight: weight)
        let font = (base.fontDescriptor.withDesign(.rounded)).flatMap { NSFont(descriptor: $0, size: 11) } ?? base
        return ceil((s as NSString).size(withAttributes: [.font: font]).width) + 6
    }
}

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var theme: ThemeModel
    // Observed only so the surface re-lays-out when the "ears" toggle changes.
    @AppStorage("liveEars") private var liveEars = true
    @AppStorage("glassMode") private var glassModeRaw = GlassMode.frosted.rawValue
    private var glassMode: GlassMode { GlassMode(rawValue: glassModeRaw) ?? .frosted }

    private var expanded: Bool { notchState.isExpanded }
    private var useGlass: Bool { theme.glass && notchState.isExpanded }
    private var active: Bool { store.summary != .idle }
    private var latestSource: String? {
        (store.activities.first(where: { $0.status == .running }) ?? store.activities.first)?.source
    }

    var body: some View {
        let notchW = notchState.notchSize.width  > 0 ? notchState.notchSize.width  : NotchMetrics.fallbackNotchWidth
        let notchH = notchState.notchSize.height > 0 ? notchState.notchSize.height : NotchMetrics.fallbackNotchHeight
        let collapsedW = NotchLayout.collapsedWidth(notchWidth: notchW, active: active)
        let w = expanded ? NotchMetrics.expandedWidth  : collapsedW
        let h = expanded ? NotchMetrics.expandedHeight : notchH
        let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: expanded ? 30 : (active ? 16 : 10))

        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 0) {
                Color.clear
                    .frame(width: w, height: h)
                    .background { surfaceBackground(shape) }
                    .overlay {
                        // Render ONLY the active state — never both. Building the
                        // expanded dashboard while collapsed kept its animations
                        // (waveform/clock) running 24fps in the background and
                        // burned CPU at idle. Now collapsed = static text only.
                        ZStack {
                            if expanded {
                                ExpandedDashboard(notchHeight: notchH)
                                    .transition(.opacity)
                            } else {
                                CompactContent(notchWidth: notchW, notchHeight: notchH)
                                    .transition(.opacity)
                            }
                        }
                        .clipShape(shape)
                    }
                    .overlay {
                        CelebrationOverlay(kind: notchState.celebration)
                            .clipShape(shape)
                            .allowsHitTesting(false)
                    }
                    .modifier(ShakeIf(active: notchState.celebration == .failure))
                    // No drop shadow — it read as a grey border on light screens.

                if expanded {
                    FloatingTabBar()
                        .padding(.top, NotchMetrics.tabBarGap)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .top)
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .top)),
                            removal: .opacity))
                }
            }
        }
        .frame(width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: AnimKey(expanded: expanded, active: active))
    }

    /// The panel surface. Pitch black by default (so it disappears into the
    /// physical notch). In glass mode it's a real `NSVisualEffectView`
    /// behind-window blur of the desktop/windows behind the panel — which a
    /// transparent overlay can actually refract (SwiftUI `.glassEffect` falls
    /// back to flat here) — clipped to the notch shape with a glass edge.
    @ViewBuilder
    private func surfaceBackground(_ shape: NotchShape) -> some View {
        // Collapsed draws NO box at all (idle OR running) — painting #000 over
        // the notch reads as a faint second notch on an LCD. The running state is
        // shown by a small pulse dot (CompactContent) that floats over the menu
        // bar with no background. Only the expanded panel draws a surface.
        if !expanded {
            Color.clear
        } else if useGlass {
            switch glassMode {
            case .frosted:
                fauxGlass(shape)
            case .liquid:
                if #available(macOS 26.0, *) {
                    ZStack {
                        LiquidGlassBackground(cornerRadius: 22).clipShape(shape)
                        glassRim(shape)
                    }
                } else {
                    fauxGlass(shape)
                }
            case .live:
                ZStack {
                    LiveGlassView().clipShape(shape)
                    glassRim(shape)
                }
            }
        } else {
            shape.fill(Color.black)
        }
    }

    /// Phase 1 faux glass — reliable everywhere, zero permission: a
    /// charcoal→black gradient + fine grain + a bright top rim.
    @ViewBuilder
    private func fauxGlass(_ shape: NotchShape) -> some View {
        ZStack {
            shape.fill(
                LinearGradient(colors: [GlassStyle.topTint, GlassStyle.bottomTint],
                               startPoint: .top, endPoint: .bottom))
            NoiseTexture()
                .opacity(GlassStyle.grainOpacity)
                .blendMode(.overlay)
                .clipShape(shape)
            glassRim(shape)
        }
    }

    /// Shared glass edge: bright top rim + faint hairline.
    @ViewBuilder
    private func glassRim(_ shape: NotchShape) -> some View {
        shape.stroke(
            LinearGradient(colors: [GlassStyle.rimTop, GlassStyle.rimBottom],
                           startPoint: .top, endPoint: .bottom),
            lineWidth: 1)
        shape.stroke(GlassStyle.hairline, lineWidth: 0.5)
    }

    private struct AnimKey: Equatable { let expanded: Bool; let active: Bool }
}

// MARK: - Collapsed / compact (Dynamic-Island-style live activity)

private struct CompactContent: View {
    @EnvironmentObject var store: ActivityStore
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        if store.summary == .idle || !NotchLayout.showsEars {
            Color.clear   // nothing at rest — physical notch only
        } else {
            // A single pulse dot just right of the camera. No background box, so
            // it never looks like a second notch. Full details show on hover.
            HStack(spacing: 0) {
                Color.clear.frame(maxWidth: .infinity)   // left ear (keeps notch centered)
                Color.clear.frame(width: notchWidth)      // camera gap
                HStack(spacing: 0) {
                    PulseDot(color: dotColor)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, max(4, (notchHeight - 9) / 2))
        }
    }

    private var dotColor: Color {
        switch store.summary {
        case .success: return .green                                  // done → green
        case .failure: return .red                                    // failed → red
        default: return Color(red: 1, green: 0.36, blue: 0.45)        // running → brand red
        }
    }
}

/// A small pulsing dot with a soft glow — the collapsed "running" indicator.
private struct PulseDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.9), radius: on ? 5 : 1.5)
            .scaleEffect(on ? 1 : 0.68)
            .opacity(on ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// Confetti burst on success / red flash on failure, over the notch.
private struct CelebrationOverlay: View {
    let kind: NotchState.Celebration

    var body: some View {
        ZStack {
            if kind == .success {
                Confetti()
            } else if kind == .failure {
                Rectangle().fill(.red.opacity(0.18))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: kind)
    }
}

private struct Confetti: View {
    @State private var go = false
    private let pieces = 16
    private let colors: [Color] = [.green, .mint, .teal, .white, .yellow]

    var body: some View {
        ZStack {
            ForEach(0..<pieces, id: \.self) { i in
                let angle = Double(i) / Double(pieces) * 2 * .pi
                let dist: CGFloat = go ? 60 : 0
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: 5, height: 5)
                    .offset(x: cos(angle) * dist, y: sin(angle) * dist - (go ? 6 : 0))
                    .opacity(go ? 0 : 1)
                    .scaleEffect(go ? 0.4 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    }
}

/// A quick horizontal shake when triggered (for failures).
private struct ShakeIf: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: phase)
            .onChange(of: active) { _, on in
                guard on else { return }
                let seq = [-7.0, 7, -5, 5, -2, 2, 0]
                for (i, v) in seq.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                        withAnimation(.easeInOut(duration: 0.05)) { phase = CGFloat(v) }
                    }
                }
            }
    }
}

struct StatusGlyph: View {
    let summary: ActivityStore.Summary
    var size: CGFloat = 13

    var body: some View {
        switch summary {
        case .idle:
            Circle().fill(.white.opacity(0.35)).frame(width: size * 0.5, height: size * 0.5)
        case .running:
            ProgressView().controlSize(.small).scaleEffect(size / 22).frame(width: size, height: size)
        case .success:
            Image(systemName: "checkmark.circle.fill").font(.system(size: size, weight: .bold)).foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill").font(.system(size: size, weight: .bold)).foregroundStyle(.red)
        }
    }
}

/// A 1px divider that fades toward its ends — softer than a flat line.
private struct Hairline: View {
    enum Axis { case horizontal, vertical }
    let axis: Axis
    var body: some View {
        let grad = LinearGradient(
            colors: [.white.opacity(0.02), .white.opacity(0.12), .white.opacity(0.02)],
            startPoint: axis == .horizontal ? .leading : .top,
            endPoint: axis == .horizontal ? .trailing : .bottom)
        Rectangle().fill(grad)
            .frame(width: axis == .vertical ? 1 : nil,
                   height: axis == .horizontal ? 1 : nil)
    }
}

// MARK: - Expanded dashboard (top bar + horizontal sections)

private struct ExpandedDashboard: View {
    @EnvironmentObject var pages: PagesModel
    @EnvironmentObject var approvals: ApprovalStore
    let notchHeight: CGFloat

    private var sections: [WidgetKind] { pages.current.widgets }

    var body: some View {
        VStack(spacing: 0) {
            DashboardTopBar()
                .frame(height: max(notchHeight, 32))

            Hairline(axis: .horizontal)

            if !approvals.pending.isEmpty {
                ApprovalBanner()
            }

            if sections.isEmpty {
                Text("No widgets on this page — add some in Widgets & Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SectionsLayout()
                    .id(pages.current.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 8)   // 8 + section's 12 ≈ 20pt outer panel padding
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.22), value: pages.selectedIndex)
    }
}

// MARK: - Resizable / reorderable section row

private struct SectionsLayout: View {
    @EnvironmentObject var pages: PagesModel
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var theme: ThemeModel

    @State private var dragIndex: Int? = nil
    @State private var dragDX: CGFloat = 0

    private var sections: [WidgetKind] { pages.current.widgets }
    private var pageIdx: Int { pages.selectedIndex }

    var body: some View {
        GeometryReader { geo in
            let editing = notchState.editingLayout
            let n = sections.count
            let dividerSpace = CGFloat(max(0, n - 1)) * 9
            let avail = max(1, geo.size.width - dividerSpace)
            let weights = pages.weights(forPageAt: pageIdx)
            let sum = max(1, weights.reduce(0, +))
            let widths = weights.map { CGFloat($0 / sum) * avail }

            HStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element) { index, kind in
                    let w = index < widths.count ? widths[index] : avail / CGFloat(max(n, 1))
                    cell(index: index, kind: kind, width: w, editing: editing)

                    if index != n - 1 {
                        ResizeHandle(editing: editing) { deltaPx in
                            pages.resize(pageAt: pageIdx, divider: index,
                                         byFraction: Double(deltaPx / geo.size.width))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(index: Int, kind: WidgetKind, width: CGFloat, editing: Bool) -> some View {
        SectionView(kind: kind)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .clipped()                       // oversized content scrolls/clips, never breaks the row
            .allowsHitTesting(!editing)
            .opacity(dragIndex != nil && dragIndex != index ? 0.45 : 1)
            .overlay { if editing { editChrome(kind) } }
            .offset(x: dragIndex == index ? dragDX : 0)
            .scaleEffect(dragIndex == index ? 1.04 : 1)
            .zIndex(dragIndex == index ? 2 : 1)
            .gesture(editing ? reorderGesture(index: index, width: width) : nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragIndex)
    }

    private func reorderGesture(index: Int, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                if dragIndex == nil { dragIndex = index; Haptics.pop() }
                dragDX = v.translation.width
            }
            .onEnded { v in
                let steps = Int((v.translation.width / max(width, 1)).rounded())
                let target = max(0, min(sections.count - 1, index + steps))
                if target != index {
                    pages.moveWidget(pageAt: pageIdx, from: index, to: target)
                    Haptics.pop()
                }
                dragIndex = nil; dragDX = 0
            }
    }

    private func editChrome(_ kind: WidgetKind) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.accent.color.opacity(0.75),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            VStack(spacing: 5) {
                Image(systemName: "arrow.left.and.right").font(.system(size: 15, weight: .bold))
                Image(systemName: kind.systemImage).font(.system(size: 12))
                Text(kind.title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
        }
        .padding(4)
        .background(Color.black.opacity(0.35).clipShape(RoundedRectangle(cornerRadius: 9)).padding(4))
    }
}

/// The divider between two sections — drag it to resize the columns.
private struct ResizeHandle: View {
    let editing: Bool
    let onResize: (CGFloat) -> Void
    @State private var last: CGFloat = 0

    var body: some View {
        ZStack {
            Hairline(axis: .vertical)
            if editing {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.25))
                    .frame(width: 4, height: 28)
            }
        }
        .frame(width: 9)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    onResize(v.translation.width - last)
                    last = v.translation.width
                }
                .onEnded { _ in last = 0 }
        )
        .help("Drag to resize")
    }
}

private struct DashboardTopBar: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        HStack(spacing: 6) {
            // No brand mark / title — the floating tab row already shows the page.
            Spacer()

            if store.activities.contains(where: { $0.status != .running }) {
                Button("Clear") { store.clearFinished() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.08)))
                    .padding(.trailing, 2)
            }
            // Edit layout: drag to reorder / resize widgets in the notch.
            Button { notchState.editingLayout.toggle() } label: {
                Image(systemName: notchState.editingLayout ? "checkmark" : "rectangle.split.3x1")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(notchState.editingLayout ? theme.accent.color : .white.opacity(0.5))
                    .hoverChip()
            }
            .buttonStyle(.plain)
            .help(notchState.editingLayout ? "Done editing" : "Edit layout (drag to reorder / resize)")
            // Pin keeps the notch open while you type/read.
            Button { notchState.isPinned.toggle() } label: {
                Image(systemName: notchState.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(notchState.isPinned ? theme.accent.color : .white.opacity(0.5))
                    .hoverChip()
            }
            .buttonStyle(.plain)
            .help(notchState.isPinned ? "Unpin" : "Keep open")
            SettingsLink {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .hoverChip()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
}

/// Faint circular hover background for the top-bar icon controls.
private struct HoverChip: ViewModifier {
    @State private var hover = false
    func body(content: Content) -> some View {
        content
            .frame(width: 26, height: 26)
            .background(Circle().fill(.white.opacity(hover ? 0.12 : 0)))
            .contentShape(Circle())
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}
private extension View { func hoverChip() -> some View { modifier(HoverChip()) } }

/// Amber banner shown when an agent is waiting for an Approve/Deny decision.
private struct ApprovalBanner: View {
    @EnvironmentObject var approvals: ApprovalStore

    var body: some View {
        if let a = approvals.pending.first {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 15)).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("\(a.source) wants to run")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                        if approvals.pending.count > 1 {
                            Text("+\(approvals.pending.count - 1) more")
                                .font(.system(size: 9, weight: .medium)).foregroundStyle(.orange)
                        }
                    }
                    Text(a.command.isEmpty ? a.tool : a.command)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("Deny") { approvals.decide(a.id, allow: false) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.1)))
                Button("Approve") { approvals.decide(a.id, allow: true) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(.green))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.orange.opacity(0.14))
            .overlay(Rectangle().fill(.orange.opacity(0.4)).frame(height: 1), alignment: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Round tab buttons floating beneath the panel — switch pages. A single accent
/// pill slides between tabs (matchedGeometry) inside a dark glass capsule.
private struct FloatingTabBar: View {
    @EnvironmentObject var pages: PagesModel
    @EnvironmentObject var theme: ThemeModel
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(pages.pages.enumerated()), id: \.element.id) { index, page in
                let selected = index == pages.selectedIndex
                Button {
                    Haptics.pop()
                    pages.select(index)
                } label: {
                    Image(systemName: page.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? .black : .white.opacity(0.85))
                        .frame(width: NotchMetrics.tabButtonSize, height: NotchMetrics.tabButtonSize)
                        .background {
                            if selected {
                                Circle().fill(theme.accent.color)
                                    .matchedGeometryEffect(id: "tabSelector", in: ns)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(page.title)
            }
        }
        .padding(5)
        .background { barBackground }   // Liquid Glass (no drop shadow)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: pages.selectedIndex)
    }

    @ViewBuilder private var barBackground: some View {
        let capsule = Capsule(style: .continuous)
        if theme.glass {
            // Faux glass to match the panel (no drop shadow).
            ZStack {
                capsule.fill(
                    LinearGradient(colors: [GlassStyle.topTint, GlassStyle.bottomTint],
                                   startPoint: .top, endPoint: .bottom))
                NoiseTexture().opacity(GlassStyle.grainOpacity).blendMode(.overlay).clipShape(capsule)
                capsule.stroke(
                    LinearGradient(colors: [GlassStyle.rimTop, GlassStyle.rimBottom],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            }
        } else {
            capsule
                .fill(Color(white: 0.1).opacity(0.92))
                .overlay(capsule.stroke(.white.opacity(0.12), lineWidth: 0.8))
        }
    }
}

private struct SectionView: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .clock:    ClockSection()
        case .agent:    AgentSection()
        case .race:     RaceSection()
        case .tokens:   TokenMeterSection()
        case .battery:  BatterySection()
        case .apps:     OpenAppsSection()
        case .windows:  OpenWindowsSection()
        case .music:    MusicSection()
        case .stats:    StatsSection()
        case .pomodoro: PomodoroSection()
        case .ask:      AskSection()
        case .clipboard: ClipboardSection()
        case .shelf:    ShelfSection()
        case .camera:   CameraSection()
        case .teleprompter: TeleprompterSection()
        case .calendar: CalendarSection()
        case .todo:     TodoSection()
        case .notes:    NotesSection()
        case .dayProgress: DayProgressSection()
        case .shortcuts: ShortcutsSection()
        case .bluetooth: BluetoothSection()
        case .windowSnap: WindowSnapSection()
        }
    }
}
