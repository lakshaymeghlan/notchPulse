import SwiftUI

/// Drives the teleprompter: an editable script that auto-scrolls upward while
/// playing. Script + settings persist to UserDefaults.
@MainActor
final class TeleprompterModel: ObservableObject {
    private let scriptKey = "teleprompter.script"
    private let speedKey = "teleprompter.speed"

    @Published var script: String { didSet { UserDefaults.standard.set(script, forKey: scriptKey) } }
    @Published var speed: Double { didSet { UserDefaults.standard.set(speed, forKey: speedKey) } }   // pts/sec
    @Published private(set) var isPlaying = false
    @Published private(set) var offset: CGFloat = 0

    private var timer: Timer?
    private let tick = 1.0 / 30.0

    init() {
        script = UserDefaults.standard.string(forKey: scriptKey) ?? Self.placeholder
        let s = UserDefaults.standard.double(forKey: speedKey)
        speed = s > 0 ? s : 35
    }

    deinit { timer?.invalidate() }

    static let placeholder = """
    Welcome to NotchPulse. Tap play and read straight down the lens — your script scrolls right below the camera.

    Edit this text in Widgets & Settings. Adjust the speed with the − and + controls. Press the circle to reset to the top.
    """

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        let t = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.offset += CGFloat(self.speed * self.tick)
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

    func reset() { offset = 0 }

    func slower() { speed = max(10, speed - 10) }
    func faster() { speed = min(120, speed + 10) }

    /// Keep the offset from running off forever once we pass the end.
    func clamp(contentHeight: CGFloat, viewport: CGFloat) {
        let maxOffset = max(0, contentHeight - viewport + 20)
        if offset > maxOffset {
            offset = maxOffset
            pause()
        }
    }
}
