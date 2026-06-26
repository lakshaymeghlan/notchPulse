import Foundation
import AppKit

/// "Ask Claude" from inside the notch — runs the user's own Claude Code CLI
/// (`claude -p`) so no API key is needed; it uses their existing auth.
@MainActor
final class AskModel: ObservableObject {
    @Published var prompt: String = ""
    @Published private(set) var answer: String = ""
    @Published private(set) var isThinking = false
    @Published private(set) var error: String?

    private var process: Process?
    private var cachedClaudePath: String?

    /// Locate the `claude` binary using a login shell (GUI apps have a minimal
    /// PATH that won't include ~/.local/bin, Homebrew, or npm-global).
    private func claudePath() -> String? {
        if let p = cachedClaudePath { return p }
        let shell = Process()
        shell.launchPath = "/bin/zsh"
        shell.arguments = ["-lc", "which claude"]
        let pipe = Pipe()
        shell.standardOutput = pipe
        shell.standardError = Pipe()
        do { try shell.run() } catch { return nil }
        shell.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            cachedClaudePath = path
            return path
        }
        return nil
    }

    func summarizeClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.isEmpty else {
            error = "Clipboard is empty — copy some text first."
            return
        }
        run("Summarize this concisely:\n\n\(text)")
    }

    func submit() {
        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return }
        run(p)
    }

    func run(_ text: String) {
        guard !isThinking else { return }
        guard let claude = claudePath() else {
            error = "Couldn't find the `claude` CLI. Install Claude Code and make sure `which claude` works in your shell."
            return
        }
        error = nil
        answer = ""
        isThinking = true

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: claude)
        proc.arguments = ["-p", text, "--output-format", "text"]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        self.process = proc

        DispatchQueue.global(qos: .userInitiated).async {
            do { try proc.run() } catch {
                Task { @MainActor in
                    self.error = "Failed to launch Claude: \(error.localizedDescription)"
                    self.isThinking = false
                }
                return
            }
            proc.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Task { @MainActor in
                self.isThinking = false
                if text.isEmpty && !errText.isEmpty {
                    self.error = errText
                } else {
                    self.answer = text
                }
                self.process = nil
            }
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        isThinking = false
    }

    func clear() {
        answer = ""
        prompt = ""
        error = nil
    }
}
