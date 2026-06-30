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

    static func collapsedWidth(notchWidth: CGFloat, active: Bool) -> CGFloat {
        guard active, showsEars else { return notchWidth }
        // Snug pill — source and status hug the camera (centered by spacers).
        // (Hide the live activity entirely via Settings → Appearance.)
        return min(notchWidth + 168, 392)
    }
}

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var theme: ThemeModel
    // Observed only so the surface re-lays-out when the "ears" toggle changes.
    @AppStorage("liveEars") private var liveEars = true

    private var expanded: Bool { notchState.isExpanded }
    private var useGlass: Bool { theme.glass && notchState.isExpanded }
    private var active: Bool { store.summary != .idle }

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
                shape
                    .fill(surfaceStyle)
                    .background {
                        if useGlass { GlassBackground().clipShape(shape) }
                    }
                    .overlay {
                        ZStack {
                            CompactContent(notchWidth: notchW, notchHeight: notchH)
                                .opacity(expanded ? 0 : 1)
                            ExpandedDashboard(notchHeight: notchH)
                                .opacity(expanded ? 1 : 0)
                        }
                        .clipShape(shape)
                    }
                    .overlay {
                        // A faint sheen ONLY on the lower rounded edge — the top
                        // edge stays borderless so it blends into the bezel with
                        // no visible seam.
                        if expanded {
                            shape.stroke(
                                LinearGradient(
                                    colors: [.clear, .clear, .white.opacity(0.10)],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                        }
                    }
                    .overlay {
                        CelebrationOverlay(kind: notchState.celebration)
                            .clipShape(shape)
                            .allowsHitTesting(false)
                    }
                    .modifier(ShakeIf(active: notchState.celebration == .failure))
                    .frame(width: w, height: h)
                    .shadow(color: .black.opacity(expanded ? 0.45 : 0),
                            radius: expanded ? 22 : 0, y: expanded ? 11 : 0)

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

    /// The surface fill. Pitch black everywhere (collapsed AND expanded) so the
    /// panel disappears into the physical notch with no visible seam at the top
    /// edge. Glass mode uses a translucent wash instead (intentionally see-through).
    private var surfaceStyle: AnyShapeStyle {
        if useGlass {
            return AnyShapeStyle(LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.32)],
                startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(Color.black)
    }

    private struct AnimKey: Equatable { let expanded: Bool; let active: Bool }
}

// MARK: - Collapsed / compact (Dynamic-Island-style live activity)

private struct CompactContent: View {
    @EnvironmentObject var store: ActivityStore
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        switch store.summary {
        case .idle:
            Color.clear
        default:
            HStack(spacing: 0) {
                Spacer(minLength: 6)
                // Source — sits right against the left of the camera.
                Text(leftLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).truncationMode(.tail)
                    .padding(.trailing, 11)

                // Center gap = physical notch (camera).
                Color.clear.frame(width: notchWidth)

                // Status — sits right against the right of the camera.
                Text(rightLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(rightColor)
                    .lineLimit(1)
                    .padding(.leading, 11)
                Spacer(minLength: 6)
            }
            // Align with the menu-bar text line (top of the notch), not the
            // vertical center of the taller notch — kills the empty top space.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, max(3, (notchHeight - 15) / 2))
        }
    }

    private var latest: Activity? { store.activities.first(where: { $0.status == .running }) ?? store.activities.first }

    /// Left ear — which agent (source name), or a count when several run.
    private var leftLabel: String {
        if case .running(let n) = store.summary, n > 1 { return "\(n) agents" }
        return latest?.source ?? latest?.title ?? "Agent"
    }

    /// Right ear — the status word.
    private var rightLabel: String {
        switch store.summary {
        case .running: return "running"
        case .success: return "done"
        case .failure: return "failed"
        case .idle: return ""
        }
    }

    private var rightColor: Color {
        switch store.summary {
        case .success: return .green
        case .failure: return .red
        default: return .white.opacity(0.7)
        }
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
        .padding(.horizontal, 6)
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
                                    .shadow(color: theme.accent.color.opacity(0.5), radius: 6)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(page.title)
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(Color(white: 0.1).opacity(0.9))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.8))
        )
        .shadow(color: .black.opacity(0.4), radius: 14, y: 7)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: pages.selectedIndex)
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
