import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Shared card chrome for widgets: subtle translucent panel inside the notch.
struct WidgetCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack(spacing: 5) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(.white.opacity(0.45))
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}

// MARK: - Clock

struct ClockWidget: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            WidgetCard(title: "Clock", systemImage: "clock") {
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}

// MARK: - Battery

struct BatteryWidget: View {
    @EnvironmentObject var battery: BatteryMonitor

    var body: some View {
        WidgetCard(title: "Battery", systemImage: "bolt.fill") {
            HStack(spacing: 10) {
                Image(systemName: battery.symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(battery.isPresent ? "\(battery.level)%" : "—")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(stateLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
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

// MARK: - Shelf (drag-and-drop file stash)

struct ShelfWidget: View {
    @EnvironmentObject var shelf: ShelfStore
    @State private var targeted = false

    var body: some View {
        WidgetCard(title: "Shelf", systemImage: "tray.full") {
            Group {
                if shelf.items.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 12))
                        Text("Drag files here to stash them")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(targeted ? 0.9 : 0.45))
                    .frame(maxWidth: .infinity, minHeight: 38)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(shelf.items) { item in
                                ShelfChip(item: item)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.white.opacity(targeted ? 0.6 : 0.12))
            )
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                handleDrop(providers)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                if let url {
                    DispatchQueue.main.async { shelf.add([url]) }
                }
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
        VStack(spacing: 3) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 30, height: 30)
            Text(item.name)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .frame(maxWidth: 56)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(hovering ? 0.12 : 0.0))
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture { shelf.open(item) }
        .help(item.url.path)
        // Drag the file back out to Finder / another app.
        .onDrag { NSItemProvider(object: item.url as NSURL) }
    }
}
