import EventKit
import Combine
import Foundation

/// Reads the user's upcoming events via EventKit. Access is requested lazily
/// (only when the Calendar widget is shown), never at launch.
@MainActor
final class CalendarMonitor: ObservableObject {
    struct Item: Identifiable {
        let id: String
        let title: String
        let start: Date
        let isAllDay: Bool
        let color: CGColor?
        /// A Zoom / Meet / Teams / Webex link pulled from the event, if any.
        let joinURL: URL?

        /// True for a timed event starting within the next 10 minutes (or already
        /// underway) — the moment the "Join" button matters most.
        var isImminent: Bool {
            guard !isAllDay else { return false }
            let delta = start.timeIntervalSinceNow
            return delta < 600 && delta > -1800
        }
    }

    enum Access { case unknown, granted, denied }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var events: [Item] = []
    /// Day numbers in the current month that have at least one event (for the grid).
    @Published private(set) var monthEventDays: Set<Int> = []

    private let store = EKEventStore()
    private var timer: Timer?

    init() { refreshAuthorization() }

    deinit { timer?.invalidate() }

    private func refreshAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            access = .granted
            load()
            startTimer()
        case .denied, .restricted:
            access = .denied
        default:
            access = .unknown
        }
    }

    /// Ask for access (drives the system prompt the first time).
    func requestAccess() {
        let handler: (Bool, Error?) -> Void = { granted, _ in
            Task { @MainActor in
                self.access = granted ? .granted : .denied
                if granted { self.load(); self.startTimer() }
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: handler)
        } else {
            store.requestAccess(to: .event, completion: handler)
        }
    }

    func load() {
        let cal = Calendar.current
        let now = Date()
        guard let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map {
                Item(id: $0.eventIdentifier ?? UUID().uuidString,
                     title: $0.title ?? "Event",
                     start: $0.startDate,
                     isAllDay: $0.isAllDay,
                     color: $0.calendar?.cgColor,
                     joinURL: Self.meetingLink(in: $0))
            }

        // Which days this month have events (for the month grid).
        if let month = cal.dateInterval(of: .month, for: now) {
            let pred = store.predicateForEvents(withStart: month.start, end: month.end, calendars: nil)
            monthEventDays = Set(store.events(matching: pred).map { cal.component(.day, from: $0.startDate) })
        }
    }

    /// Best-effort extraction of a video-call link from an event: its URL field
    /// first, then any link found in the location or notes.
    private static func meetingLink(in event: EKEvent) -> URL? {
        if let u = event.url, isMeetingHost(u.host) { return u }
        for text in [event.location, event.notes].compactMap({ $0 }) {
            if let u = firstMeetingURL(in: text) { return u }
        }
        return nil
    }

    private static let meetingHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com",
                                       "teams.live.com", "webex.com", "whereby.com", "meet.jit.si"]

    private static func isMeetingHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix(".\($0)") || host.contains($0) }
    }

    private static func firstMeetingURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            if let url = match.url, isMeetingHost(url.host) { return url }
        }
        return nil
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
        t.tolerance = 30
        timer = t
    }
}
