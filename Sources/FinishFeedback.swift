import AppKit
import AVFoundation

/// Sound + spoken announcement when an agent finishes. Both opt-in via
/// UserDefaults; defaults: sound on, speech off.
@MainActor
final class FinishFeedback {
    private let synth = AVSpeechSynthesizer()

    var soundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "finishSound") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "finishSound") }
    }
    var speechEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "finishSpeech") }
        set { UserDefaults.standard.set(newValue, forKey: "finishSpeech") }
    }

    func finished(success: Bool, title: String?, source: String?) {
        if soundEnabled {
            NSSound(named: success ? "Glass" : "Basso")?.play()
        }
        if speechEnabled {
            let who = source ?? "Agent"
            let phrase = success ? "\(who) finished." : "\(who) failed."
            let u = AVSpeechUtterance(string: phrase)
            u.rate = 0.52
            u.volume = 0.9
            synth.speak(u)
        }
    }
}
