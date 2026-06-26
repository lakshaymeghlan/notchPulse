import SwiftUI

/// A switchable page ("section") of the dashboard — a named tab with its own
/// ordered set of widgets.
struct NotchPage: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var icon: String
    var widgets: [WidgetKind]
}

/// Holds the editable pages and the current selection. Pages persist to
/// UserDefaults so edits survive relaunches.
@MainActor
final class PagesModel: ObservableObject {
    private let defaultsKey = "notchPages.v3"

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
                  widgets: [.clock, .agent, .battery, .stats]),
        NotchPage(id: "focus", title: "Focus", icon: "scope",
                  widgets: [.clock, .calendar, .pomodoro, .windows]),
        NotchPage(id: "media", title: "Media", icon: "play.circle",
                  widgets: [.music, .apps, .camera, .shelf]),
        NotchPage(id: "studio", title: "Studio", icon: "text.alignleft",
                  widgets: [.teleprompter, .camera]),
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
