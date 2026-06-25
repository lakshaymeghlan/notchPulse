import SwiftUI

/// The notch silhouette: flush square top (it meets the bezel), rounded bottom
/// corners — exactly the hardware-notch shape. Small inner top fillets soften
/// where it leaves the bezel, like macnotch / Dynamic Island.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topCornerRadius, rect.height / 2))
        let br = max(0, min(bottomCornerRadius, rect.height - tr, rect.width / 2))
        var p = Path()
        // Start at the top-left, flush with the bezel.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top-left fillet curving down into the left side.
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )
        // Left side down to the bottom-left rounded corner.
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr, y: rect.maxY)
        )
        // Bottom edge to the bottom-right rounded corner.
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
        )
        // Right side up to the top-right fillet.
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore

    private var expanded: Bool { notchState.isExpanded }

    var body: some View {
        let shape = NotchShape(
            topCornerRadius: 8,
            bottomCornerRadius: expanded ? 22 : 10
        )

        ZStack {
            shape.fill(.black)

            Group {
                if expanded {
                    ExpandedCard(notchHeight: notchState.notchSize.height)
                } else {
                    CollapsedContent(cameraGap: cameraGap)
                }
            }
        }
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(shape)
        .onHover { hovering in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                notchState.isHovering = hovering
            }
        }
    }

    /// Roughly the camera/sensor cluster width to leave clear in the collapsed
    /// top strip.
    private var cameraGap: CGFloat {
        let w = notchState.notchSize.width
        return w > 0 ? min(90, w * 0.42) : 0
    }
}

// MARK: - Collapsed (lives at exact notch size; content sits in the "ears")

private struct CollapsedContent: View {
    @EnvironmentObject var store: ActivityStore
    let cameraGap: CGFloat

    var body: some View {
        // Idle ⇒ pure black notch (blends with the hardware). Otherwise show a
        // status glyph on the left ear and a count on the right ear, straddling
        // the camera.
        Group {
            switch store.summary {
            case .idle:
                Color.clear
            default:
                HStack(spacing: 0) {
                    StatusGlyph(summary: store.summary, size: 12)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: cameraGap)
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

/// Spinner / check / cross used in both the ear and the rows.
private struct StatusGlyph: View {
    let summary: ActivityStore.Summary
    var size: CGFloat = 13

    var body: some View {
        switch summary {
        case .idle:
            Circle().fill(.white.opacity(0.35)).frame(width: size * 0.5, height: size * 0.5)
        case .running:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(size / 22)
                .frame(width: size, height: size)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Expanded card (top strip kept clear of the camera)

private struct ExpandedCard: View {
    @EnvironmentObject var store: ActivityStore
    let notchHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row sits just under the camera strip.
            HStack {
                Text("NotchPulse")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if store.activities.contains(where: { $0.status != .running }) {
                    Button("Clear") { store.clearFinished() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if store.activities.isEmpty {
                Text("No activity")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.activities) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
            }
        }
        // Clear the camera/sensor strip at the very top, plus side/bottom insets.
        .padding(.top, max(notchHeight, 28) + 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            StatusGlyph(summary: glyphSummary, size: 13)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let detail = activity.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                if activity.status == .running, let p = activity.progress {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(height: 3)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var glyphSummary: ActivityStore.Summary {
        switch activity.status {
        case .running: return .running(count: 1)
        case .success: return .success
        case .failure: return .failure(count: 1)
        }
    }
}
