import SwiftUI

struct NotchView: View {
    @EnvironmentObject var notchState: NotchState
    @EnvironmentObject var store: ActivityStore

    var body: some View {
        ZStack {
            // Black backdrop blends into the physical notch; reads as a floating
            // pill on non-notched displays.
            RoundedRectangle(cornerRadius: notchState.isExpanded ? 18 : 12, style: .continuous)
                .fill(.black)

            Group {
                if notchState.isExpanded {
                    ExpandedCard()
                } else {
                    CollapsedPill()
                }
            }
            .padding(.horizontal, notchState.isExpanded ? 12 : 8)
            .padding(.vertical, notchState.isExpanded ? 10 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                notchState.isExpanded = hovering
            }
        }
    }
}

// MARK: - Collapsed pill

private struct CollapsedPill: View {
    @EnvironmentObject var store: ActivityStore

    var body: some View {
        HStack(spacing: 6) {
            StatusGlyph(summary: store.summary)
            if let label = countLabel {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var countLabel: String? {
        switch store.summary {
        case .idle: return nil
        case .running(let n): return n > 1 ? "\(n)" : nil
        case .success: return nil
        case .failure(let n): return n > 1 ? "\(n)" : nil
        }
    }
}

/// The status indicator shared by the pill: spinner / check / cross.
private struct StatusGlyph: View {
    let summary: ActivityStore.Summary

    var body: some View {
        switch summary {
        case .idle:
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: 7, height: 7)
        case .running:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
                .frame(width: 14, height: 14)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Expanded card

private struct ExpandedCard: View {
    @EnvironmentObject var store: ActivityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NotchPulse")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            rowGlyph
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

    @ViewBuilder private var rowGlyph: some View {
        switch activity.status {
        case .running:
            ProgressView().controlSize(.small).scaleEffect(0.6)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 13))
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 13))
        }
    }
}
