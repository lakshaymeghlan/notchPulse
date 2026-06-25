import SwiftUI

/// A switchable page ("section") of the dashboard — a named tab with its own
/// ordered set of widgets. The user flips between these from the top bar.
struct NotchPage: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let widgets: [WidgetKind]
}

/// Holds the available pages and the current selection. Defaults ship a few
/// curated pages; widgets still respect the per-widget toggles in Settings.
@MainActor
final class PagesModel: ObservableObject {
    @Published var pages: [NotchPage]
    @Published var selectedIndex: Int = 0

    init() {
        pages = [
            NotchPage(id: "dashboard", title: "Dashboard", icon: "square.grid.2x2",
                      widgets: [.clock, .agent, .battery, .apps]),
            NotchPage(id: "focus", title: "Focus", icon: "scope",
                      widgets: [.clock, .calendar, .agent, .shelf]),
            NotchPage(id: "media", title: "Media", icon: "play.circle",
                      widgets: [.clock, .camera, .battery]),
        ]
    }

    var current: NotchPage {
        pages[min(max(selectedIndex, 0), pages.count - 1)]
    }

    func select(_ index: Int) {
        selectedIndex = min(max(index, 0), pages.count - 1)
    }

    func next() { select((selectedIndex + 1) % pages.count) }
    func previous() { select((selectedIndex - 1 + pages.count) % pages.count) }
}
