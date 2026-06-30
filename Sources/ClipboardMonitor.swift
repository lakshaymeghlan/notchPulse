import AppKit
import Combine

/// Keeps a short history of copied text. Local only — nothing leaves the Mac.
@MainActor
final class ClipboardMonitor: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    @Published private(set) var items: [Item] = []
    private let max = 8
    private var lastChange = NSPasteboard.general.changeCount
    private var timer: Timer?

    init() {
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = 0.4
        timer = t
    }

    deinit { timer?.invalidate() }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        guard let s = pb.string(forType: .string) else { return }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if items.first?.text == trimmed { return }
        items.removeAll { $0.text == trimmed }
        items.insert(Item(text: trimmed), at: 0)
        if items.count > max { items.removeLast(items.count - max) }
    }

    func copy(_ item: Item) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChange = pb.changeCount   // don't re-record our own write
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func clear() { items.removeAll() }
}
