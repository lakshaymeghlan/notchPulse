import SwiftUI

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
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                       control: CGPoint(x: rect.minX + tr, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                       control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                       control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Shared sizing so the view and the window controller agree on the shape rect.
enum NotchLayout {
    static func collapsedWidth(notchWidth: CGFloat, active: Bool) -> CGFloat {
        // Compact (Dynamic-Island-style) when there's activity, else exact notch.
        active ? min(notchWidth + 230, NotchMetrics.expandedWidth) : notchWidth
    }
}

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore

    private var expanded: Bool { notchState.isExpanded }
    private var active: Bool { store.summary != .idle }

    var body: some View {
        let notchW = notchState.notchSize.width  > 0 ? notchState.notchSize.width  : NotchMetrics.fallbackNotchWidth
        let notchH = notchState.notchSize.height > 0 ? notchState.notchSize.height : NotchMetrics.fallbackNotchHeight
        let collapsedW = NotchLayout.collapsedWidth(notchWidth: notchW, active: active)
        let w = expanded ? NotchMetrics.expandedWidth  : collapsedW
        let h = expanded ? NotchMetrics.expandedHeight : notchH
        let shape = NotchShape(topCornerRadius: 9, bottomCornerRadius: expanded ? 26 : (active ? 14 : 10))

        ZStack(alignment: .top) {
            Color.clear
            shape
                .fill(.black)
                .overlay {
                    ZStack {
                        CompactContent(notchHeight: notchH)
                            .opacity(expanded ? 0 : 1)
                        ExpandedDashboard(notchHeight: notchH)
                            .opacity(expanded ? 1 : 0)
                    }
                    .clipShape(shape)
                }
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 18, y: 8)
        }
        .frame(width: NotchMetrics.windowWidth, height: NotchMetrics.windowHeight, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: AnimKey(expanded: expanded, active: active))
    }

    private struct AnimKey: Equatable { let expanded: Bool; let active: Bool }
}

// MARK: - Collapsed / compact (Dynamic-Island-style live activity)

private struct CompactContent: View {
    @EnvironmentObject var store: ActivityStore
    let notchHeight: CGFloat

    var body: some View {
        switch store.summary {
        case .idle:
            Color.clear
        default:
            HStack(spacing: 8) {
                StatusGlyph(summary: store.summary, size: 13)
                Text(leadingLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 78)   // clear the camera
                Text(trailingLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(trailingColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var latest: Activity? { store.activities.first(where: { $0.status == .running }) ?? store.activities.first }

    private var leadingLabel: String {
        guard let a = latest else { return "" }
        return a.source ?? a.title
    }

    private var trailingLabel: String {
        switch store.summary {
        case .running:
            if let p = latest?.progress { return "\(Int(p * 100))%" }
            return "Running"
        case .success: return "Done"
        case .failure: return "Failed"
        case .idle: return ""
        }
    }

    private var trailingColor: Color {
        switch store.summary {
        case .success: return .green
        case .failure: return .red
        default: return .white.opacity(0.7)
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

// MARK: - Expanded dashboard (top bar + horizontal sections)

private struct ExpandedDashboard: View {
    @EnvironmentObject var widgets: WidgetSettings
    @EnvironmentObject var pages: PagesModel
    let notchHeight: CGFloat

    private var sections: [WidgetKind] {
        pages.current.widgets.filter { widgets.isOn($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DashboardTopBar()
                .frame(height: max(notchHeight, 32))

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

            Group {
                if sections.isEmpty {
                    Text("No widgets on this page — add some in Widgets & Settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        ForEach(Array(sections.enumerated()), id: \.element) { index, kind in
                            SectionView(kind: kind)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if index != sections.count - 1 {
                                Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                            }
                        }
                    }
                }
            }
            .id(pages.current.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 6)
        .animation(.easeInOut(duration: 0.2), value: pages.selectedIndex)
    }
}

private struct DashboardTopBar: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var pages: PagesModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform").font(.system(size: 11, weight: .bold))

            // Visible page switcher (segmented pill).
            HStack(spacing: 2) {
                ForEach(Array(pages.pages.enumerated()), id: \.element.id) { index, page in
                    let selected = index == pages.selectedIndex
                    Button {
                        pages.select(index)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: page.icon).font(.system(size: 10, weight: .semibold))
                            if selected {
                                Text(page.title).font(.system(size: 10, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, selected ? 9 : 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(.white.opacity(selected ? 0.18 : 0.0))
                        )
                        .foregroundStyle(.white.opacity(selected ? 0.95 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(page.title)
                }
            }
            .padding(2)
            .background(Capsule().fill(.white.opacity(0.05)))

            Spacer()

            if store.activities.contains(where: { $0.status != .running }) {
                Button("Clear") { store.clearFinished() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            SettingsLink {
                Image(systemName: "slider.horizontal.3").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 14)
    }
}

private struct SectionView: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .clock:    ClockSection()
        case .agent:    AgentSection()
        case .battery:  BatterySection()
        case .apps:     OpenAppsSection()
        case .windows:  OpenWindowsSection()
        case .music:    MusicSection()
        case .shelf:    ShelfSection()
        case .camera:   CameraSection()
        case .calendar: CalendarSection()
        }
    }
}
