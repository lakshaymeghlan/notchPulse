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

    var body: some View {
        NotchSection(title: "Music", systemImage: "music.note") {
            if let track = music.track {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(track.artist.isEmpty ? track.app : track.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    HStack(spacing: 16) {
                        MusicButton(icon: "backward.fill") { music.previous() }
                        MusicButton(icon: track.isPlaying ? "pause.fill" : "play.fill") { music.playPause() }
                        MusicButton(icon: "forward.fill") { music.next() }
                    }
                    .padding(.top, 1)
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
        }
        .buttonStyle(.plain)
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
                GeometryReader { geo in
                    Text(prompter.script)
                        .font(.system(size: 15, weight: .medium))
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
                }

                HStack(spacing: 12) {
                    Button { prompter.togglePlay() } label: {
                        Image(systemName: prompter.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Button { prompter.reset() } label: {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 12, weight: .semibold))
                    }
                    // Live timer: elapsed / total.
                    Text("\(TeleprompterModel.clock(prompter.elapsed)) / \(TeleprompterModel.clock(prompter.totalSeconds))")
                        .font(.system(size: 10, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    Button { prompter.slower() } label: { Image(systemName: "tortoise.fill").font(.system(size: 11)) }
                    Text("\(Int(prompter.speed))").font(.system(size: 10, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7)).frame(width: 22)
                    Button { prompter.faster() } label: { Image(systemName: "hare.fill").font(.system(size: 11)) }

                    SettingsLink {
                        Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                    }
                    .help("Edit script")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .buttonStyle(.plain)
            }
        }
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
