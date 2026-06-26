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
                    HStack(spacing: 6) {
                        PulsingDot(color: theme.accent.color)
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
                HStack(spacing: 8) {
                    StatusGlyph(summary: last.status == .failure ? .failure(count: 1) : .success, size: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(last.title).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                        Text(last.status == .failure ? "Failed" : "Done")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
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
            ProgressView().controlSize(.small).scaleEffect(0.55).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(primary).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Text(activity.source ?? "Agent")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(theme.accent.color)
                    Text("#\(String(activity.id.suffix(4)))")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4)).monospaced()
                }
                if let p = activity.progress {
                    ProgressView(value: p).progressViewStyle(.linear).tint(theme.accent.color).frame(height: 2.5)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var primary: String {
        if let d = activity.detail, !d.isEmpty { return d }
        return activity.title
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

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 6)]

    var body: some View {
        NotchSection(title: "Open Apps", systemImage: "square.grid.2x2") {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
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
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(calendar.events) { ev in
                            HStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ev.color.map { Color(cgColor: $0) } ?? .blue)
                                    .frame(width: 3, height: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ev.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white).lineLimit(1)
                                    Text(ev.isAllDay ? "All day" : ev.start.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }
}
