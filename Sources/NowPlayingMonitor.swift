import AppKit
import Combine

/// Now-playing for Spotify / Apple Music via AppleScript. Public-API only (no
/// private MediaRemote): we only talk to a player that's already running, so we
/// never launch one. The first query triggers the system Automation prompt.
@MainActor
final class NowPlayingMonitor: ObservableObject {
    struct Track: Equatable {
        var title: String
        var artist: String
        var app: String        // "Spotify" | "Music"
        var isPlaying: Bool
        var position: Double = 0   // seconds
        var duration: Double = 0   // seconds
        var artworkURL: String = ""
    }

    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var permissionNeeded = false
    private var artworkURLLoaded = ""

    private var timer: Timer?
    private let queue = DispatchQueue(label: "io.notchpulse.nowplaying")

    private struct Player { let bundleID: String; let appName: String }
    private let players = [
        Player(bundleID: "com.spotify.client", appName: "Spotify"),
        Player(bundleID: "com.apple.Music", appName: "Music"),
    ]

    func startPolling() {
        guard timer == nil else { return }
        refresh()
        let t = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 0.5
        timer = t
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// The first running player we find (and only that one — we never launch one).
    private var activePlayer: Player? {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return players.first { running.contains($0.bundleID) }
    }

    func refresh() {
        guard let player = activePlayer else { track = nil; return }
        queue.async { [weak self] in
            guard let self else { return }
            let script = """
            tell application "\(player.appName)"
                set st to (player state as string)
                set t to ""
                set a to ""
                set dur to 0
                set pos to 0
                set art to ""
                try
                    set t to name of current track
                    set a to artist of current track
                    set dur to duration of current track
                    set pos to player position
                end try
                try
                    set art to artwork url of current track
                end try
                return st & "\\n" & t & "\\n" & a & "\\n" & (pos as string) & "\\n" & (dur as string) & "\\n" & art
            end tell
            """
            var errorInfo: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
            Task { @MainActor in
                self.handle(result: result, error: errorInfo, player: player)
            }
        }
    }

    private func handle(result: NSAppleEventDescriptor?, error: NSDictionary?, player: Player) {
        if let error {
            // -1743 = not authorized (Automation). Surface a hint, clear track.
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            permissionNeeded = (code == -1743)
            track = nil
            return
        }
        permissionNeeded = false
        guard let string = result?.stringValue else { track = nil; return }
        let parts = string.components(separatedBy: "\n")
        guard parts.count >= 3 else { track = nil; return }
        let state = parts[0].lowercased()
        let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { track = nil; artwork = nil; return }

        let position = parts.count > 3 ? (Double(parts[3].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
        var duration = parts.count > 4 ? (Double(parts[4].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
        // Spotify reports duration in milliseconds; Apple Music in seconds.
        if player.appName == "Spotify" { duration /= 1000 }
        let artURL = parts.count > 5 ? parts[5].trimmingCharacters(in: .whitespacesAndNewlines) : ""

        track = Track(title: title, artist: artist, app: player.appName,
                      isPlaying: state.contains("playing"),
                      position: position, duration: duration, artworkURL: artURL)
        loadArtwork(artURL)
    }

    private func loadArtwork(_ urlString: String) {
        guard urlString != artworkURLLoaded else { return }
        artworkURLLoaded = urlString
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            artwork = nil; return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { NSImage(data: $0) }
            Task { @MainActor in
                // Only apply if still the current track's art.
                if self.track?.artworkURL == urlString { self.artwork = image }
            }
        }.resume()
    }

    func seek(to seconds: Double) {
        guard let player = activePlayer else { return }
        queue.async { [weak self] in
            let script = "tell application \"\(player.appName)\" to set player position to \(Int(seconds))"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Controls

    func playPause() { control("playpause") }
    func next() { control("next track") }
    func previous() { control("previous track") }

    private func control(_ command: String) {
        guard let player = activePlayer else { return }
        queue.async { [weak self] in
            let script = "tell application \"\(player.appName)\" to \(command)"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            Task { @MainActor in self?.refresh() }
        }
    }
}
