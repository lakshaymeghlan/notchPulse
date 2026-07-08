import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// App/file icons. (Icons may look gray if the display's Grayscale color filter
/// is on — that's a system setting, not the app.)
struct AppIcon: View {
    let image: NSImage
    var side: CGFloat
    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: side, height: side)
    }
}

/// Resolves and caches an app icon from a bundle id or (fuzzy) app name.
@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage?] = [:]

    static func icon(for identifier: String) -> NSImage? {
        if let cached = cache[identifier] { return cached }
        let ws = NSWorkspace.shared
        var img: NSImage?
        if identifier.contains("."), let url = ws.urlForApplication(withBundleIdentifier: identifier) {
            img = ws.icon(forFile: url.path)
        }
        if img == nil,
           let app = ws.runningApplications.first(where: {
               ($0.localizedName ?? "").localizedCaseInsensitiveContains(identifier)
           }), let url = app.bundleURL {
            img = ws.icon(forFile: url.path)
        }
        cache[identifier] = img
        return img
    }
}

/// Shows the owning app's real icon when resolvable, else a fallback view.
struct SourceIcon<Fallback: View>: View {
    let identifier: String?
    var side: CGFloat = 16
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if let id = identifier, let img = AppIconCache.icon(for: id) {
            Image(nsImage: img).resizable().interpolation(.high)
                .frame(width: side, height: side)
        } else {
            fallback()
        }
    }
}

/// An on-brand animated audio waveform — the "pulse" in NotchPulse. Reacts while
/// `active`; settles flat when not.
struct Waveform: View {
    var color: Color = .white
    var bars: Int = 5
    var active: Bool = true
    var maxHeight: CGFloat = 13

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule().fill(color)
                        .frame(width: 2.5, height: height(i, t))
                }
            }
            .frame(height: maxHeight, alignment: .center)
        }
    }

    private func height(_ i: Int, _ t: Double) -> CGFloat {
        guard active else { return 3 }
        let phase = Double(i) * 0.7
        let unit = 0.5 + 0.5 * sin(t * 5.2 + phase)
        return 3 + (maxHeight - 3) * unit
    }
}

/// Section chrome: a small header (icon + caps title) above content, laid out
/// top-leading to fill its column. Matches the macnotch-style divided panel.
struct NotchSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content
    @EnvironmentObject private var theme: ThemeModel

    var body: some View {
        // 8pt scale: header→content gap 8, internal content gaps owned by each
        // section (target 10). Consistent header treatment across all sections.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.accent.color.opacity(0.9))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.5))
            }
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)   // 12 + 12 between columns ≈ 24pt gap
        .padding(.vertical, 14)
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
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ctx.date, format: .dateTime.weekday(.wide))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    Text(ctx.date, format: .dateTime.month(.wide).day())
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Agent (live Claude Code / tool activity — the core)

struct AgentSection: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var theme: ThemeModel

    private var running: [Activity] { store.activities.filter { $0.status == .running } }
    private var latest: Activity? { store.activities.first }

    var body: some View {
        NotchSection(title: "Agent", systemImage: "waveform.path.ecg") {
            if !running.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Waveform(color: theme.accent.color, bars: 4, maxHeight: 12)
                            .frame(width: 18)
                        Text(running.count > 1 ? "\(running.count) agents running" : "Running")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent.color)
                    }
                    // One lane per running session — two Claude Codes show as two.
                    ForEach(running.prefix(3)) { activity in
                        AgentLane(activity: activity)
                    }
                    if running.count > 3 {
                        Text("+\(running.count - 3) more")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            } else if let last = latest {
                HStack(alignment: .top, spacing: 8) {
                    StatusGlyph(summary: last.status == .failure ? .failure(count: 1) : .success, size: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.title).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                        Text(last.status == .failure ? "Failed" : "Done")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                        if let summary = last.summaryLine {
                            Text(summary)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if let app = last.app {
                        FocusAppButton(identifier: app)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Idle").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Waiting for agent tasks…")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }
}

/// One running agent session (distinct lane). Shows the current action and a
/// short session id so two Claude Code sessions are distinguishable.
private struct AgentLane: View {
    let activity: Activity
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            SourceIcon(identifier: activity.app, side: 16) {
                ProgressView().controlSize(.small).scaleEffect(0.55).frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(primary).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Text(activity.source ?? "Agent")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(theme.accent.color)
                    Text("#\(String(activity.id.suffix(4)))")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4)).monospaced()
                    if let eta = activity.etaSeconds() {
                        Text("· \(etaLabel(eta))")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                if let p = activity.progress {
                    ProgressView(value: p).progressViewStyle(.linear).tint(theme.accent.color).frame(height: 2.5)
                }
            }
            Spacer(minLength: 0)
            if let app = activity.app {
                FocusAppButton(identifier: app)
            }
        }
    }

    private var primary: String {
        if let d = activity.detail, !d.isEmpty { return d }
        return activity.title
    }
}

/// One-tap "Focus" back to the terminal/editor that owns an agent task.
struct FocusAppButton: View {
    let identifier: String
    var body: some View {
        Button { AppFocus.activate(identifier) } label: {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .help("Focus \(identifier)")
    }
}

/// Bring a running app to the front by bundle id or (fuzzy) name.
enum AppFocus {
    static func activate(_ identifier: String) {
        let apps = NSWorkspace.shared.runningApplications
        let match = apps.first { $0.bundleIdentifier == identifier }
            ?? apps.first { $0.localizedName == identifier }
            ?? apps.first { ($0.localizedName ?? "").localizedCaseInsensitiveContains(identifier) }
        match?.activate()
    }
}

// MARK: - Agent race (multiple agents racing to the finish)

/// When several agents run at once, show them as lanes racing to a finish line,
/// ranked live by progress. Great for parallel Claude Code sessions.
struct RaceSection: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var theme: ThemeModel

    private var racers: [Activity] {
        store.activities
            .filter { $0.status == .running }
            .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
    }

    var body: some View {
        NotchSection(title: "Agent Race", systemImage: "flag.checkered") {
            if racers.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("On your marks…").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Run two or more agents to see them race.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(racers.prefix(4).enumerated()), id: \.element.id) { idx, a in
                        RaceLane(rank: idx + 1, activity: a, color: theme.accent.color)
                    }
                    if racers.count > 4 {
                        Text("+\(racers.count - 4) more in the pack")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
    }
}

private struct RaceLane: View {
    let rank: Int
    let activity: Activity
    let color: Color

    private var p: CGFloat { CGFloat(min(max(activity.progress ?? 0, 0), 1)) }
    private var hasProgress: Bool { activity.progress != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(medal).font(.system(size: 11))
                Text(activity.source ?? activity.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                Text("#\(String(activity.id.suffix(4)))")
                    .font(.system(size: 8)).monospaced().foregroundStyle(.white.opacity(0.35))
                if let eta = activity.etaSeconds() {
                    Text(etaLabel(eta))
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 4)
                Text(hasProgress ? "\(Int(p * 100))%" : "…")
                    .font(.system(size: 9, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: p)
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 5)
                    if hasProgress {
                        Capsule().fill(color)
                            .frame(width: max(4, w * p), height: 5)
                            .animation(.easeInOut(duration: 0.4), value: p)
                    } else {
                        // No progress reported — show an indeterminate shimmer.
                        IndeterminateBar(color: color).frame(height: 5)
                    }
                    Image(systemName: rank == 1 ? "hare.fill" : "tortoise.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .offset(x: min(w - 10, max(0, w * p - 5)))
                        .animation(.easeInOut(duration: 0.4), value: p)
                    // Finish line.
                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1.5)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: 12)
        }
    }

    private var medal: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "🏁"
        }
    }
}

/// A looping shimmer for racers that report no numeric progress.
private struct IndeterminateBar: View {
    let color: Color
    @State private var x: CGFloat = -0.4
    var body: some View {
        GeometryReader { geo in
            Capsule().fill(color.opacity(0.8))
                .frame(width: geo.size.width * 0.35)
                .offset(x: x * geo.size.width)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                        x = 1.05
                    }
                }
        }
    }
}

// MARK: - Tokens & cost meter

/// Live, session-wide token count and running cost across all agents. Values
/// arrive on the event API (`tokens`, `cost`) — any integration can post them.
struct TokenMeterSection: View {
    @EnvironmentObject var store: ActivityStore
    @EnvironmentObject var theme: ThemeModel

    private var totalTokens: Int { store.activities.compactMap(\.tokens).reduce(0, +) }
    private var totalCost: Double { store.activities.compactMap(\.cost).reduce(0, +) }
    private var hasData: Bool { totalTokens > 0 || totalCost > 0 }

    var body: some View {
        NotchSection(title: "Tokens & Cost", systemImage: "dollarsign.circle") {
            if !hasData {
                VStack(alignment: .leading, spacing: 3) {
                    Text("$0.00").font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("No usage reported yet.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(costString)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent.color)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: totalCost)
                    HStack(spacing: 5) {
                        Image(systemName: "number").font(.system(size: 10, weight: .bold))
                        Text(tokenString).font(.system(size: 12, weight: .semibold))
                            .monospacedDigit().contentTransition(.numericText())
                        Text("tokens").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    .foregroundStyle(.white)
                    .animation(.snappy, value: totalTokens)
                }
            }
        }
    }

    private var costString: String {
        String(format: totalCost >= 10 ? "$%.2f" : "$%.3f", totalCost)
    }
    private var tokenString: String {
        let t = totalTokens
        if t >= 1_000_000 { return String(format: "%.2fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.1fk", Double(t) / 1_000) }
        return "\(t)"
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
            HStack(spacing: 12) {
                // Circular ring gauge.
                ZStack {
                    Circle().stroke(.white.opacity(0.14), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: CGFloat(battery.isPresent ? battery.level : 0) / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: battery.level)
                    if battery.isCharging || battery.isPluggedIn {
                        Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(tint)
                    } else {
                        Text("\(battery.isPresent ? battery.level : 0)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit().foregroundStyle(.white)
                    }
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 1) {
                    Text(battery.isPresent ? "\(battery.level)%" : "—")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white).monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: battery.level)
                    Text(stateLabel)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
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

    // Equal 12pt gaps, consistent icon size; icons never touch the edges.
    private let columns = [GridItem(.adaptive(minimum: 34), spacing: 12)]

    var body: some View {
        NotchSection(title: "Open Apps", systemImage: "square.grid.2x2") {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(openApps.apps) { app in
                        if let icon = app.icon {
                            Button {
                                openApps.activate(app)
                            } label: {
                                AppIcon(image: icon, side: 32)
                            }
                            .buttonStyle(.plain)
                            .help("Focus \(app.name)")
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}

// MARK: - Open windows

struct OpenWindowsSection: View {
    @EnvironmentObject var windows: WindowsMonitor

    var body: some View {
        NotchSection(title: "Open Windows", systemImage: "macwindow.on.rectangle") {
            if windows.windows.isEmpty {
                Text("No windows").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(windows.windows) { win in
                            Button {
                                windows.activate(win)
                            } label: {
                                HStack(spacing: 7) {
                                    if let icon = win.icon {
                                        AppIcon(image: icon, side: 16)
                                    }
                                    Text(win.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                            .help(win.appName)
                        }
                        if !windows.canReadTitles {
                            Button {
                                windows.requestTitleAccess()
                            } label: {
                                Text("Enable titles…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Grant Screen Recording to show window titles")
                        }
                    }
                }
            }
        }
        .onAppear { windows.startPolling() }
        .onDisappear { windows.stopPolling() }
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
            AppIcon(image: item.icon, side: 28)
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

// MARK: - Music (Spotify / Apple Music)

struct MusicSection: View {
    @EnvironmentObject var music: NowPlayingMonitor
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        NotchSection(title: "Music", systemImage: "music.note") {
            if let track = music.track {
                HStack(alignment: .top, spacing: 10) {
                    // Album art (Spotify provides a URL; placeholder otherwise).
                    Group {
                        if let art = music.artwork {
                            Image(nsImage: art).resizable().interpolation(.high)
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08))
                                .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.4)))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.title).font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white).lineLimit(1)
                                Text(track.artist.isEmpty ? track.app : track.artist)
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            EqualizerBars(active: track.isPlaying, color: theme.accent.color)
                                .frame(width: 20, height: 16)
                        }
                        MusicScrubber(position: track.position, duration: track.duration, tint: theme.accent.color) {
                            music.seek(to: $0)
                        }
                        HStack(spacing: 14) {
                            MusicButton(icon: "backward.fill") { music.previous() }
                            MusicButton(icon: track.isPlaying ? "pause.fill" : "play.fill") { music.playPause() }
                            MusicButton(icon: "forward.fill") { music.next() }
                        }
                    }
                }
            } else if music.permissionNeeded {
                Text("Allow control in System Settings → Automation")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "music.note").font(.system(size: 13))
                    Text("Nothing playing").font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .onAppear { music.startPolling() }
        .onDisappear { music.stopPolling() }
    }
}

private struct MusicButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Animated audio-style bars (premium now-playing flourish).
struct EqualizerBars: View {
    var active: Bool
    var color: Color = .white
    private let count = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(active ? 0.95 : 0.4))
                        .frame(width: 3, height: barHeight(i, t))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func barHeight(_ i: Int, _ t: Double) -> CGFloat {
        guard active else { return 4 }
        let phase = Double(i) * 0.7
        return 4 + 13 * (0.5 + 0.5 * sin(t * 6.0 + phase))
    }
}

/// Seekable progress bar for the Music widget.
struct MusicScrubber: View {
    let position: Double
    let duration: Double
    let tint: Color
    let onSeek: (Double) -> Void
    @State private var dragging = false
    @State private var temp = 0.0

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { dragging ? temp : position },
                    set: { temp = $0 }
                ),
                in: 0...max(duration, 1),
                onEditingChanged: { editing in
                    if editing { dragging = true } else { dragging = false; onSeek(temp) }
                }
            )
            .controlSize(.mini)
            .tint(tint)
            HStack {
                Text(clock(dragging ? temp : position))
                Spacer()
                Text(clock(duration))
            }
            .font(.system(size: 9, weight: .medium)).monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func clock(_ s: Double) -> String {
        let t = Int(max(0, s)); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - System stats

struct StatsSection: View {
    @EnvironmentObject var stats: SystemStatsMonitor
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        NotchSection(title: "System", systemImage: "cpu") {
            VStack(alignment: .leading, spacing: 10) {
                StatRow(label: "CPU", value: stats.cpu, history: stats.cpuHistory, color: theme.accent.color)
                StatRow(label: "MEM", value: stats.memory, history: stats.memHistory, color: .blue)
            }
        }
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }
}

private struct StatRow: View {
    let label: String
    let value: Double
    let history: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(Int(value * 100))%").font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
            }
            Sparkline(values: history, color: color).frame(height: 22)
        }
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if values.count > 1 {
                    let pts = points(w: w, h: h)
                    // Fill under the line.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }

    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        return values.enumerated().map { i, v in
            CGPoint(x: w * CGFloat(i) / CGFloat(values.count - 1), y: h * (1 - CGFloat(min(max(v, 0), 1))))
        }
    }
}

// MARK: - Pomodoro

struct PomodoroSection: View {
    @EnvironmentObject var pomo: PomodoroModel
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        NotchSection(title: "Pomodoro", systemImage: "timer") {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(.white.opacity(0.14), lineWidth: 4)
                    Circle().trim(from: 0, to: pomo.progress)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: pomo.progress)
                    Text(PomodoroModel.clock(pomo.remaining))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(pomo.phase.rawValue)
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(phaseColor)
                    Text("\(pomo.completedSessions) done")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 12) {
                        MusicButton(icon: pomo.isRunning ? "pause.fill" : "play.fill") { pomo.toggle() }
                        MusicButton(icon: "arrow.counterclockwise") { pomo.reset() }
                        MusicButton(icon: "forward.end.fill") { pomo.skip() }
                    }
                }
            }
        }
    }

    private var phaseColor: Color { pomo.phase == .work ? theme.accent.color : .orange }
}

// MARK: - Ask Claude

struct AskSection: View {
    @EnvironmentObject var ask: AskModel
    @EnvironmentObject var theme: ThemeModel
    @FocusState private var focused: Bool

    var body: some View {
        NotchSection(title: "Ask Claude", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Ask or summarize…", text: $ask.prompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .focused($focused)
                        .onSubmit { ask.submit() }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.08)))
                    Button {
                        ask.isThinking ? ask.cancel() : ask.submit()
                    } label: {
                        Image(systemName: ask.isThinking ? "stop.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(theme.accent.color)
                    }
                    .buttonStyle(.plain)
                }

                Button { ask.summarizeClipboard() } label: {
                    Label("Summarize clipboard", systemImage: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Divider().overlay(.white.opacity(0.08))

                ScrollView(.vertical, showsIndicators: false) {
                    if ask.isThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text("Thinking…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        }
                    } else if let err = ask.error {
                        Text(err).font(.system(size: 11)).foregroundStyle(.red.opacity(0.9))
                    } else if !ask.answer.isEmpty {
                        Text(ask.answer)
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Answers appear here. Tip: pin the notch (📌) to keep it open.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
    }
}

// MARK: - Clipboard history

struct ClipboardSection: View {
    @EnvironmentObject var clipboard: ClipboardMonitor
    @State private var copied: UUID?

    var body: some View {
        NotchSection(title: "Clipboard", systemImage: "doc.on.clipboard") {
            if clipboard.items.isEmpty {
                Text("Copy something — it'll show up here.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(clipboard.items) { item in
                            Button {
                                clipboard.copy(item)
                                copied = item.id
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: copied == item.id ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundStyle(copied == item.id ? .green : .white.opacity(0.4))
                                        .frame(width: 12)
                                    Text(item.text.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                            .help(item.text)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera mirror

struct CameraSection: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var notchState: NotchState

    var body: some View {
        NotchSection(title: "Camera", systemImage: "camera") {
            Group {
                if !camera.isOn {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash.fill").font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                        Button { camera.toggle() } label: {
                            Text("Turn on")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(.white.opacity(0.14)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if camera.permission == .denied {
                    VStack(spacing: 4) {
                        Image(systemName: "video.slash").font(.system(size: 16))
                        Text("Access denied").font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    CameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topTrailing) {
                            Button { camera.toggle() } label: {
                                Image(systemName: "power")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(5)
                                    .background(Circle().fill(.black.opacity(0.55)))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        }
                }
            }
        }
        // The session only runs while this section is visible AND the user
        // turned it on.
        .onAppear { camera.setVisible(notchState.isExpanded) }
        .onChange(of: notchState.isExpanded) { _, expanded in camera.setVisible(expanded) }
        .onDisappear { camera.setVisible(false) }
    }
}

// MARK: - Teleprompter

struct TeleprompterSection: View {
    @EnvironmentObject var prompter: TeleprompterModel

    var body: some View {
        NotchSection(title: "Teleprompter", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: 6) {
                // Scrolling script (flexible height).
                GeometryReader { geo in
                    Text(prompter.script)
                        .font(.system(size: prompter.fontSize, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .frame(width: geo.size.width, alignment: .topLeading)
                        // Force the text to its FULL natural height before we
                        // measure it — otherwise the parent's (short) height
                        // proposal clamps it and maxOffset comes out ~0 (no scroll).
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            GeometryReader { textGeo in
                                Color.clear
                                    .onAppear { prompter.measure(contentHeight: textGeo.size.height, viewport: geo.size.height) }
                                    .onChange(of: textGeo.size.height) { _, h in
                                        prompter.measure(contentHeight: h, viewport: geo.size.height)
                                    }
                            }
                        )
                        .offset(y: -prompter.offset)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                        .clipped()
                        .allowsHitTesting(false)   // never let the text eat control taps
                }
                .frame(maxHeight: .infinity)

                // Controls — fixed row, generous tap targets.
                HStack(spacing: 4) {
                    PrompterControl(prompter.isPlaying ? "pause.fill" : "play.fill") { prompter.togglePlay() }
                    PrompterControl("arrow.counterclockwise") { prompter.reset() }

                    Spacer(minLength: 2)

                    // Text size.
                    PrompterControl("textformat.size.smaller") { prompter.smallerText() }
                    PrompterControl("textformat.size.larger") { prompter.biggerText() }

                    Divider().frame(height: 16).overlay(.white.opacity(0.2))

                    // Scroll speed.
                    PrompterControl("tortoise.fill") { prompter.slower() }
                    Text("\(Int(prompter.speed))")
                        .font(.system(size: 10, weight: .bold)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85)).frame(width: 22)
                    PrompterControl("hare.fill") { prompter.faster() }

                    SettingsLink {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 26, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Edit script")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A teleprompter control button with a large, reliable tap area.
private struct PrompterControl: View {
    let icon: String
    let action: () -> Void
    init(_ icon: String, action: @escaping () -> Void) { self.icon = icon; self.action = action }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar

// MARK: - To-Do

struct TodoSection: View {
    @EnvironmentObject var todo: TodoModel
    @EnvironmentObject var theme: ThemeModel
    @State private var draft = ""

    var body: some View {
        NotchSection(title: "To-Do", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    TextField("Add a task…", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .onSubmit { todo.add(draft); draft = "" }
                    Button { todo.add(draft); draft = "" } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14))
                            .foregroundStyle(theme.accent.color)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.07)))

                if todo.items.isEmpty {
                    Text("Nothing yet — add your first task.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(todo.items) { item in
                                Button { todo.toggle(item) } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(item.done ? theme.accent.color : .white.opacity(0.4))
                                        Text(item.text)
                                            .font(.system(size: 11))
                                            .foregroundStyle(item.done ? .white.opacity(0.4) : .white)
                                            .strikethrough(item.done)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notes (quick scratchpad)

struct NotesSection: View {
    @EnvironmentObject var notes: NotesModel

    var body: some View {
        NotchSection(title: "Notes", systemImage: "note.text") {
            ZStack(alignment: .topLeading) {
                if notes.text.isEmpty {
                    Text("Jot something…")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2).padding(.leading, 4)
                }
                TextEditor(text: $notes.text)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Day progress

struct DayProgressSection: View {
    @EnvironmentObject var theme: ThemeModel
    @AppStorage("day.startHour") private var startHour = 9
    @AppStorage("day.endHour") private var endHour = 18

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let p = progress(now: ctx.date)
            NotchSection(title: "Day Progress", systemImage: "sun.max") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(p * 100))%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).monospacedDigit()
                        .contentTransition(.numericText()).animation(.snappy, value: p)
                    ProgressView(value: p).progressViewStyle(.linear).tint(theme.accent.color)
                    Text(subtitle(now: ctx.date, p: p))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func progress(now: Date) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: now),
              let end = cal.date(bySettingHour: max(endHour, startHour + 1), minute: 0, second: 0, of: now)
        else { return 0 }
        let total = end.timeIntervalSince(start)
        let done = now.timeIntervalSince(start)
        return min(max(done / total, 0), 1)
    }
    private func subtitle(now: Date, p: Double) -> String {
        if p <= 0 { return "Workday starts at \(startHour):00" }
        if p >= 1 { return "Workday complete 🎉" }
        let cal = Calendar.current
        guard let end = cal.date(bySettingHour: max(endHour, startHour + 1), minute: 0, second: 0, of: now) else { return "" }
        let mins = Int(end.timeIntervalSince(now) / 60)
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m left today" : "\(mins)m left today"
    }
}

// MARK: - Keyboard shortcuts cheat-sheet

struct ShortcutsSection: View {
    @EnvironmentObject var shortcuts: ShortcutsModel

    var body: some View {
        NotchSection(title: "Shortcuts", systemImage: "keyboard") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(shortcuts.items) { s in
                        HStack(spacing: 8) {
                            Text(s.keys)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.12)))
                                .fixedSize()
                            Text(s.label)
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Bluetooth

struct BluetoothSection: View {
    @EnvironmentObject var bluetooth: BluetoothMonitor
    @EnvironmentObject var theme: ThemeModel

    var body: some View {
        NotchSection(title: "Bluetooth", systemImage: "wave.3.right") {
            if bluetooth.devices.isEmpty {
                Text("No paired devices")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(bluetooth.devices) { d in
                            HStack(spacing: 8) {
                                Image(systemName: d.symbol)
                                    .font(.system(size: 12))
                                    .foregroundStyle(d.connected ? theme.accent.color : .white.opacity(0.4))
                                    .frame(width: 18)
                                Text(d.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(d.connected ? .white : .white.opacity(0.5))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if d.connected {
                                    Circle().fill(theme.accent.color).frame(width: 5, height: 5)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Window snap

struct WindowSnapSection: View {
    @State private var trusted = WindowSnap.trusted

    private let slots: [(WindowSnap.Slot, String, String)] = [
        (.left, "rectangle.lefthalf.filled", "Left"),
        (.right, "rectangle.righthalf.filled", "Right"),
        (.top, "rectangle.tophalf.filled", "Top"),
        (.bottom, "rectangle.bottomhalf.filled", "Bottom"),
        (.full, "rectangle.fill", "Full"),
        (.center, "rectangle.center.inset.filled", "Center"),
    ]
    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 6)]

    var body: some View {
        NotchSection(title: "Window Snap", systemImage: "macwindow") {
            if !trusted {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Needs Accessibility access to move windows.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                    Button {
                        WindowSnap.requestAccess()
                        trusted = WindowSnap.trusted
                    } label: {
                        Text("Grant access").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue)
                    }.buttonStyle(.plain)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(slots, id: \.2) { slot, icon, label in
                            Button { WindowSnap.snap(slot) } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: icon).font(.system(size: 15, weight: .medium))
                                    Text(label).font(.system(size: 8, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

/// One-tap "Join" for an event that carries a video-call link. Pulses gently
/// when the meeting is imminent so it's easy to catch from the corner of your eye.
private struct JoinButton: View {
    let url: URL
    let emphasized: Bool
    @State private var pulse = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "video.fill").font(.system(size: 9, weight: .bold))
                Text("Join").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(emphasized ? .white : .green)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(
                Capsule().fill(emphasized ? Color.green : Color.green.opacity(0.16))
            )
            .scaleEffect(emphasized && pulse ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
        .onAppear {
            guard emphasized else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct CalendarSection: View {
    @EnvironmentObject var calendar: CalendarMonitor

    var body: some View {
        NotchSection(title: "Calendar", systemImage: "calendar") {
            switch calendar.access {
            case .denied:
                Text("Calendar access denied")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            case .unknown:
                Button {
                    calendar.requestAccess()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.plus").font(.system(size: 11))
                        Text("Show my events").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            case .granted:
                if calendar.events.isEmpty {
                    Text("Nothing left today")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(calendar.events) { ev in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ev.color.map { Color(cgColor: $0) } ?? .blue)
                                        .frame(width: 3, height: 28)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(ev.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.white).lineLimit(1)
                                        Text(ev.isAllDay ? "All day" : ev.start.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer(minLength: 0)
                                    if let url = ev.joinURL {
                                        JoinButton(url: url, emphasized: ev.isImminent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
