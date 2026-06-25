import SwiftUI

/// The notch silhouette: square top flush with the bezel, rounded bottom — the
/// hardware-notch shape, with small inner top fillets like macnotch.
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

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore

    private var expanded: Bool { notchState.isExpanded }

    var body: some View {
        let notchW = notchState.notchSize.width  > 0 ? notchState.notchSize.width  : NotchMetrics.fallbackNotchWidth
        let notchH = notchState.notchSize.height > 0 ? notchState.notchSize.height : NotchMetrics.fallbackNotchHeight
        let w = expanded ? NotchMetrics.expandedWidth  : notchW
        let h = expanded ? NotchMetrics.expandedHeight : notchH
        let shape = NotchShape(topCornerRadius: 9, bottomCornerRadius: expanded ? 26 : 10)

        ZStack(alignment: .top) {
            Color.clear
            shape
                .fill(.black)
                .overlay {
                    ZStack {
                        CollapsedContent(notchHeight: notchH)
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
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: expanded)
    }
}

// MARK: - Collapsed (exact notch; status in the "ears")

private struct CollapsedContent: View {
    @EnvironmentObject var store: ActivityStore
    let notchHeight: CGFloat

    var body: some View {
        Group {
            switch store.summary {
            case .idle:
                Color.clear
            default:
                HStack(spacing: 0) {
                    StatusGlyph(summary: store.summary, size: 12)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 86)
                    Text(rightLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rightLabel: String {
        switch store.summary {
        case .running(let n): return n > 1 ? "\(n)" : ""
        case .failure(let n): return n > 1 ? "\(n)" : ""
        default: return ""
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
        // Current page's widgets, minus any the user disabled globally.
        pages.current.widgets.filter { widgets.isOn($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DashboardTopBar()
                .frame(height: max(notchHeight, 30))

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
            // Cross-fade when switching pages.
            .id(pages.current.id)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: pages.selectedIndex)
    }
}

private struct DashboardTopBar: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var pages: PagesModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .bold))
            Text(pages.current.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .contentTransition(.identity)

            Spacer()

            // Page tabs — switch sections.
            HStack(spacing: 4) {
                ForEach(Array(pages.pages.enumerated()), id: \.element.id) { index, page in
                    Button {
                        pages.select(index)
                    } label: {
                        Image(systemName: page.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.white.opacity(index == pages.selectedIndex ? 0.16 : 0))
                            )
                            .foregroundStyle(.white.opacity(index == pages.selectedIndex ? 0.95 : 0.45))
                    }
                    .buttonStyle(.plain)
                    .help(page.title)
                }
            }

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
        .padding(.horizontal, 16)
    }
}

/// Routes a widget kind to its section view.
private struct SectionView: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .clock:    ClockSection()
        case .agent:    AgentSection()
        case .battery:  BatterySection()
        case .apps:     OpenAppsSection()
        case .shelf:    ShelfSection()
        case .camera:   CameraSection()
        case .calendar: CalendarSection()
        }
    }
}
