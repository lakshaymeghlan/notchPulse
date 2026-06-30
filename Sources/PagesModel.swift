import SwiftUI

/// A switchable page ("section") of the dashboard — a named tab with its own
/// ordered set of widgets.
struct NotchPage: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var icon: String
    var widgets: [WidgetKind]
    /// Relative column widths, parallel to `widgets`. nil ⇒ equal widths.
    var weights: [Double]? = nil
}

/// Holds the editable pages and the current selection. Pages persist to
/// UserDefaults so edits survive relaunches.
@MainActor
final class PagesModel: ObservableObject {
    private let defaultsKey = "notchPages.v5"

    @Published var pages: [NotchPage] { didSet { persist() } }
    @Published var selectedIndex: Int = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([NotchPage].self, from: data),
           !decoded.isEmpty {
            pages = decoded
        } else {
            pages = PagesModel.defaultPages
        }
    }

    static let defaultPages: [NotchPage] = [
        NotchPage(id: "dashboard", title: "Dashboard", icon: "square.grid.2x2",
                  widgets: [.clock, .agent, .apps, .stats]),
        NotchPage(id: "focus", title: "Focus", icon: "scope",
                  widgets: [.clock, .calendar, .pomodoro, .clipboard]),
        NotchPage(id: "media", title: "Media", icon: "play.circle",
                  widgets: [.music, .battery, .camera, .shelf]),
        NotchPage(id: "studio", title: "Studio", icon: "text.alignleft",
                  widgets: [.teleprompter, .camera]),
        NotchPage(id: "ask", title: "Ask", icon: "sparkles",
                  widgets: [.ask]),
    ]

    var current: NotchPage {
        pages[min(max(selectedIndex, 0), pages.count - 1)]
    }

    func select(_ index: Int) {
        selectedIndex = min(max(index, 0), pages.count - 1)
    }

    // MARK: - Editing

    func isWidget(_ kind: WidgetKind, onPage pageID: String) -> Bool {
        pages.first(where: { $0.id == pageID })?.widgets.contains(kind) ?? false
    }

    func setWidget(_ kind: WidgetKind, onPage pageID: String, included: Bool) {
        guard let i = pages.firstIndex(where: { $0.id == pageID }) else { return }
        if included {
            if !pages[i].widgets.contains(kind) { pages[i].widgets.append(kind) }
        } else {
            pages[i].widgets.removeAll { $0 == kind }
        }
    }

    func moveWidgets(onPage pageID: String, from source: IndexSet, to destination: Int) {
        guard let i = pages.firstIndex(where: { $0.id == pageID }) else { return }
        pages[i].widgets.move(fromOffsets: source, toOffset: destination)
        pages[i].weights = nil   // re-equalize after a settings reorder
    }

    // MARK: - In-notch layout (reorder + resize)

    /// Normalized column weights for the current page (always sums to widget count
    /// of entries; equal when unset or stale).
    func weights(forPageAt i: Int) -> [Double] {
        let n = pages[i].widgets.count
        guard n > 0 else { return [] }
        if let w = pages[i].weights, w.count == n {
            let sum = w.reduce(0, +)
            return sum > 0 ? w.map { $0 / sum * Double(n) } : Array(repeating: 1, count: n)
        }
        return Array(repeating: 1, count: n)
    }

    /// Drag a divider: shift width between the two adjacent columns.
    func resize(pageAt i: Int, divider d: Int, byFraction frac: Double) {
        var w = weights(forPageAt: i)
        guard w.indices.contains(d), w.indices.contains(d + 1) else { return }
        let total = Double(w.count)               // weights sum to count
        let minW = 0.30                            // never collapse a column too far
        let delta = frac * total
        var a = w[d] + delta, b = w[d + 1] - delta
        if a < minW { b -= (minW - a); a = minW }
        if b < minW { a -= (minW - b); b = minW }
        w[d] = a; w[d + 1] = b
        pages[i].weights = w
    }

    /// Move a column from one index to another (in-notch drag reorder).
    func moveWidget(pageAt i: Int, from: Int, to: Int) {
        var widgets = pages[i].widgets
        guard widgets.indices.contains(from) else { return }
        var w = weights(forPageAt: i)
        let dest = max(0, min(to, widgets.count - 1))
        guard dest != from else { return }
        let kind = widgets.remove(at: from)
        let weight = w.remove(at: from)
        widgets.insert(kind, at: dest)
        w.insert(weight, at: dest)
        pages[i].widgets = widgets
        pages[i].weights = w
    }

    func resetToDefaults() {
        pages = PagesModel.defaultPages
        selectedIndex = 0
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pages) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
