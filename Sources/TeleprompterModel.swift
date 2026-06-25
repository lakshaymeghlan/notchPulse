import SwiftUI

/// Drives the teleprompter: an editable script that auto-scrolls upward while
/// playing, with adjustable speed, a play timer, and a "finish in N minutes"
/// mode. Script + speed persist to UserDefaults.
@MainActor
final class TeleprompterModel: ObservableObject {
    private let scriptKey = "teleprompter.script"
    private let speedKey = "teleprompter.speed"
    private let fontKey = "teleprompter.fontSize"

    @Published var script: String { didSet { UserDefaults.standard.set(script, forKey: scriptKey) } }
    @Published var speed: Double { didSet { UserDefaults.standard.set(speed, forKey: speedKey) } }   // pts/sec
    @Published var fontSize: Double { didSet { UserDefaults.standard.set(fontSize, forKey: fontKey) } }
    @Published private(set) var isPlaying = false
    @Published private(set) var offset: CGFloat = 0
    @Published private(set) var elapsed: Double = 0   // seconds of playback

    // Measured from the rendered text so we can show total time / auto-speed.
    @Published private(set) var contentHeight: CGFloat = 0
    private var viewport: CGFloat = 0

    private var timer: Timer?
    private let tick = 1.0 / 30.0

    init() {
        script = UserDefaults.standard.string(forKey: scriptKey) ?? Self.placeholder
        let s = UserDefaults.standard.double(forKey: speedKey)
        speed = s > 0 ? s : 35
        let f = UserDefaults.standard.double(forKey: fontKey)
        fontSize = f > 0 ? f : 16
    }

    deinit { timer?.invalidate() }

    static let placeholder = """
    Welcome to NotchPulse. Tap play and read straight down the lens — your script scrolls right below the camera.

    Edit this text in Widgets & Settings (or the pencil here). Use − / + to change speed, or set how long the whole script should take.
    """

    // MARK: - Geometry / timing

    /// How far the text can scroll before the end reaches the top.
    var maxOffset: CGFloat { max(0, contentHeight - viewport + 24) }
    /// Estimated total run time at the current speed.
    var totalSeconds: Double { speed > 0 ? Double(maxOffset) / speed : 0 }
    var remainingSeconds: Double { max(0, Double(maxOffset - offset) / max(speed, 1)) }

    func measure(contentHeight: CGFloat, viewport: CGFloat) {
        self.contentHeight = contentHeight
        self.viewport = viewport
        if offset > maxOffset { offset = maxOffset; pause() }
    }

    // MARK: - Controls

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard !isPlaying else { return }
        if offset >= maxOffset && maxOffset > 0 { reset() }   // restart if at the end
        isPlaying = true
        let t = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.offset += CGFloat(self.speed * self.tick)
                self.elapsed += self.tick
                if self.maxOffset > 0 && self.offset >= self.maxOffset { self.pause() }
            }
        }
        t.tolerance = tick / 2
        timer = t
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func reset() { offset = 0; elapsed = 0 }

    func slower() { speed = max(8, speed - 8) }
    func faster() { speed = min(200, speed + 8) }

    func smallerText() { fontSize = max(10, fontSize - 2) }
    func biggerText() { fontSize = min(40, fontSize + 2) }

    /// Set the speed so the whole script scrolls past in `seconds`.
    func setDuration(_ seconds: Double) {
        guard maxOffset > 0, seconds > 0 else { return }
        speed = min(200, max(8, Double(maxOffset) / seconds))
    }

    static func clock(_ s: Double) -> String {
        let total = Int(s.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
