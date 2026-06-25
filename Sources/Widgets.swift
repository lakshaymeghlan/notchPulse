import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Section chrome: a small header (icon + caps title) above content, laid out
/// top-leading to fill its column. Matches the macnotch-style divided panel.
struct NotchSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(.white.opacity(0.4))
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Clock

struct ClockSection: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            NotchSection(title: "Clock", systemImage: "clock") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.date, format: .dateTime.hour().minute())
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(ctx.date, format: .dateTime.weekday(.wide))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(ctx.date, format: .dateTime.month(.wide).day())
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Agent (live Claude Code / tool activity — the core)

struct AgentSection: View {
    @EnvironmentObject var store: ActivityStore

    private var running: [Activity] { store.activities.filter { $0.status == .running } }
    private var latest: Activity? { store.activities.first }

    var body: some View {
        NotchSection(title: "Agent", systemImage: "waveform.path.ecg") {
            if let current = running.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        PulsingDot(color: .green)
                        Text(running.count > 1 ? "Running · \(running.count) tasks" : "Running")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    Text(current.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let detail = current.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    if let p = current.progress {
                        ProgressView(value: p).progressViewStyle(.linear).tint(.green).frame(height: 3)
                    }
                }
            } else if let last = latest {
                HStack(spacing: 8) {
                    StatusGlyph(summary: last.status == .failure ? .failure(count: 1) : .success, size: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(last.status == .failure ? "Failed" : "Done")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Idle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Waiting for agent tasks…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }
}

struct PulsingDot: View {
    var color: Color = .green
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(on ? 1 : 0.35)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

// MARK: - Battery

struct BatterySection: View {
    @EnvironmentObject var battery: BatteryMonitor

    var body: some View {
        NotchSection(title: "Battery", systemImage: "bolt.fill") {
            HStack(spacing: 10) {
                Image(systemName: battery.symbolName)
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(battery.isPresent ? "\(battery.level)%" : "—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(stateLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    private var tint: Color {
        if battery.isCharging || battery.isPluggedIn { return .green }
        return battery.level < 20 ? .red : .white
    }
    private var stateLabel: String {
        if !battery.isPresent { return "No battery" }
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged in" }
        return "On battery"
    }
}

// MARK: - Open apps

struct OpenAppsSection: View {
    @EnvironmentObject var openApps: OpenAppsMonitor

    private let columns = [GridItem(.adaptive(minimum: 34), spacing: 6)]

    var body: some View {
        NotchSection(title: "Open Apps", systemImage: "square.grid.2x2") {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(openApps.apps) { app in
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .opacity(app.isActive ? 1 : 0.7)
                                .help(app.name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shelf (drag-and-drop file stash)

struct ShelfSection: View {
    @EnvironmentObject var shelf: ShelfStore
    @State private var targeted = false

    var body: some View {
        NotchSection(title: "Shelf", systemImage: "tray.full") {
            Group {
                if shelf.items.isEmpty {
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc").font(.system(size: 14))
                        Text("Drop files").font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(targeted ? 0.9 : 0.4))
                    .frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 6)], spacing: 6) {
                            ForEach(shelf.items) { ShelfChip(item: $0) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.white.opacity(targeted ? 0.6 : 0.12))
            )
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in handleDrop(providers) }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let u = item as? URL { url = u }
                if let url { DispatchQueue.main.async { shelf.add([url]) } }
            }
        }
        return handled
    }
}

private struct ShelfChip: View {
    @EnvironmentObject var shelf: ShelfStore
    let item: ShelfStore.Item
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: item.icon).resizable().frame(width: 28, height: 28)
            Text(item.name).font(.system(size: 8)).foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).frame(maxWidth: 50)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(hovering ? 0.12 : 0)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                        .foregroundStyle(.white, .black.opacity(0.5))
                }.buttonStyle(.plain).offset(x: 3, y: -3)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture { shelf.open(item) }
        .help(item.url.path)
        .onDrag { NSItemProvider(object: item.url as NSURL) }
    }
}

// MARK: - Stage B placeholders (Camera / Calendar)

struct CameraSection: View {
    var body: some View {
        NotchSection(title: "Camera", systemImage: "camera") {
            Text("Coming next").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
        }
    }
}

struct CalendarSection: View {
    var body: some View {
        NotchSection(title: "Calendar", systemImage: "calendar") {
            Text("Coming next").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
        }
    }
}
