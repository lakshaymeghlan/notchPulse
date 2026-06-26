import SwiftUI
import AppKit

/// A focus timer with work/break cycles. Durations persist.
@MainActor
final class PomodoroModel: ObservableObject {
    enum Phase: String { case work = "Focus", shortBreak = "Break" }

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int       // seconds
    @Published private(set) var isRunning = false
    @Published private(set) var completedSessions = 0

    @Published var workMinutes: Int { didSet { UserDefaults.standard.set(workMinutes, forKey: "pomo.work"); if !isRunning && phase == .work { remaining = workMinutes * 60 } } }
    @Published var breakMinutes: Int { didSet { UserDefaults.standard.set(breakMinutes, forKey: "pomo.break"); if !isRunning && phase == .shortBreak { remaining = breakMinutes * 60 } } }

    private var timer: Timer?

    init() {
        let w = UserDefaults.standard.integer(forKey: "pomo.work")
        let b = UserDefaults.standard.integer(forKey: "pomo.break")
        workMinutes = w > 0 ? w : 25
        breakMinutes = b > 0 ? b : 5
        remaining = (w > 0 ? w : 25) * 60
    }

    deinit { timer?.invalidate() }

    var total: Int { (phase == .work ? workMinutes : breakMinutes) * 60 }
    var progress: Double { total > 0 ? Double(total - remaining) / Double(total) : 0 }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.1
        timer = t
    }

    func pause() { isRunning = false; timer?.invalidate(); timer = nil }

    func reset() { pause(); remaining = total }

    func skip() { advancePhase() }

    private func tick() {
        guard remaining > 0 else { advancePhase(); return }
        remaining -= 1
        if remaining == 0 { finishPhase() }
    }

    private func finishPhase() {
        NSSound(named: "Glass")?.play()
        if phase == .work { completedSessions += 1 }
        advancePhase()
    }

    private func advancePhase() {
        phase = (phase == .work) ? .shortBreak : .work
        remaining = total
        // keep running into the next phase
    }

    static func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
