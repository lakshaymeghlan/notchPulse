import SwiftUI
import Foundation

/// Wire format for incoming events. All fields except `event` are optional so a
/// malformed/sparse payload still decodes and is handled defensively.
struct ActivityEvent: Codable {
    enum Kind: String, Codable {
        case start, progress, update, complete, fail
    }

    let event: Kind
    var id: String?
    var title: String?
    var source: String?
    var detail: String?
    var progress: Double?
    /// Cumulative tokens used by this activity (for the Tokens & Cost meter).
    var tokens: Int?
    /// Cumulative cost in USD for this activity.
    var cost: Double?
}

/// A single tracked activity, as shown in the notch.
struct Activity: Identifiable, Equatable {
    enum Status: Equatable {
        case running
        case success
        case failure
    }

    let id: String
    var title: String
    var source: String?
    var detail: String?
    var progress: Double?
    var tokens: Int?
    var cost: Double?
    var status: Status
    var createdAt: Date
    var updatedAt: Date
}

/// Single source of truth for what the notch displays. All mutation funnels
/// through `apply(_:)`. Marked @MainActor since it drives SwiftUI directly.
@MainActor
final class ActivityStore: ObservableObject {

    /// Newest first.
    @Published private(set) var activities: [Activity] = []

    /// How long a successful activity lingers before auto-pruning.
    private let successLinger: TimeInterval = 8

    /// A running activity that gets no updates for this long is considered
    /// finished/abandoned (e.g. the tool exited without sending `complete`, or
    /// the Stop hook didn't fire) and is cleared so the notch doesn't show
    /// "running" forever.
    private let staleRunningTimeout: TimeInterval = 90

    /// Pending auto-prune tasks, keyed by activity id, so a fresh update can
    /// cancel a scheduled removal.
    private var pruneTasks: [String: Task<Void, Never>] = [:]
    private var staleTimer: Timer?

    // Injectable clock so the (default) implementation stays testable.
    private let now: () -> Date
    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        let t = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pruneStaleRunning() }
        }
        t.tolerance = 5
        staleTimer = t
    }

    deinit { staleTimer?.invalidate() }

    /// Remove running activities that have gone quiet past the timeout.
    private func pruneStaleRunning() {
        let cutoff = now().addingTimeInterval(-staleRunningTimeout)
        let stale = activities.filter { $0.status == .running && $0.updatedAt < cutoff }
        guard !stale.isEmpty else { return }
        for a in stale { cancelPrune(a.id) }
        activities.removeAll { a in stale.contains(where: { $0.id == a.id }) }
    }

    /// Fired after any event is applied (after the mutation completes, so it
    /// runs outside the @Published emission). The window controller uses this to
    /// peek the notch open — more reliable than observing `$activities`, whose
    /// sink can fire mid-`willSet`.
    var onActivity: (() -> Void)?

    // MARK: - Derived summary (drives the collapsed pill)

    enum Summary: Equatable {
        case idle
        case running(count: Int)
        case success
        case failure(count: Int)
    }

    var summary: Summary {
        if activities.isEmpty { return .idle }
        let failures = activities.filter { $0.status == .failure }.count
        if failures > 0 { return .failure(count: failures) }
        let running = activities.filter { $0.status == .running }.count
        if running > 0 { return .running(count: running) }
        return .success
    }

    var hasContent: Bool { !activities.isEmpty }

    // MARK: - Mutation

    func apply(_ event: ActivityEvent) {
        let id = resolveID(for: event)

        switch event.event {
        case .start:
            cancelPrune(id)
            upsert(id: id) { existing in
                var a = existing ?? Activity(
                    id: id,
                    title: event.title ?? defaultTitle(event),
                    source: event.source,
                    detail: event.detail,
                    progress: event.progress,
                    status: .running,
                    createdAt: now(),
                    updatedAt: now()
                )
                a.status = .running
                apply(fields: event, to: &a)
                return a
            }

        case .progress, .update:
            cancelPrune(id)
            upsert(id: id) { existing in
                var a = existing ?? newActivity(id: id, event: event, status: .running)
                a.status = .running
                apply(fields: event, to: &a)
                return a
            }

        case .complete:
            upsert(id: id) { existing in
                var a = existing ?? newActivity(id: id, event: event, status: .success)
                a.status = .success
                if a.progress != nil { a.progress = 1.0 }
                apply(fields: event, to: &a)
                return a
            }
            schedulePrune(id)

        case .fail:
            // Failures persist until explicitly cleared.
            cancelPrune(id)
            upsert(id: id) { existing in
                var a = existing ?? newActivity(id: id, event: event, status: .failure)
                a.status = .failure
                apply(fields: event, to: &a)
                return a
            }
        }

        onActivity?()
    }

    func clear(id: String) {
        cancelPrune(id)
        activities.removeAll { $0.id == id }
    }

    func clearFinished() {
        for a in activities where a.status != .running {
            cancelPrune(a.id)
        }
        activities.removeAll { $0.status != .running }
    }

    func clearAll() {
        for (_, task) in pruneTasks { task.cancel() }
        pruneTasks.removeAll()
        activities.removeAll()
    }

    // MARK: - Helpers

    /// Resolve which activity an event targets. Explicit id wins; otherwise the
    /// most-recently-updated running activity; otherwise a fresh generated id.
    private func resolveID(for event: ActivityEvent) -> String {
        if let id = event.id, !id.isEmpty { return id }
        if event.event != .start,
           let recent = activities.first(where: { $0.status == .running }) {
            return recent.id
        }
        return UUID().uuidString
    }

    private func defaultTitle(_ event: ActivityEvent) -> String {
        event.source ?? "Activity"
    }

    private func newActivity(id: String, event: ActivityEvent, status: Activity.Status) -> Activity {
        Activity(
            id: id,
            title: event.title ?? defaultTitle(event),
            source: event.source,
            detail: event.detail,
            progress: event.progress,
            status: status,
            createdAt: now(),
            updatedAt: now()
        )
    }

    /// Apply any present optional fields onto an existing activity (nil = leave).
    private func apply(fields event: ActivityEvent, to a: inout Activity) {
        if let t = event.title { a.title = t }
        if let s = event.source { a.source = s }
        if let d = event.detail { a.detail = d }
        if let p = event.progress { a.progress = min(max(p, 0), 1) }
        // Tokens/cost are cumulative — take the larger so out-of-order or
        // partial updates never make the meter run backwards.
        if let t = event.tokens { a.tokens = max(a.tokens ?? 0, t) }
        if let c = event.cost { a.cost = max(a.cost ?? 0, c) }
        a.updatedAt = now()
    }

    private func upsert(id: String, _ transform: (Activity?) -> Activity) {
        if let idx = activities.firstIndex(where: { $0.id == id }) {
            activities[idx] = transform(activities[idx])
        } else {
            // Insert newest-first.
            activities.insert(transform(nil), at: 0)
        }
    }

    private func schedulePrune(_ id: String) {
        cancelPrune(id)
        let linger = successLinger
        pruneTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(linger * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                // Only prune if still a success (a late update may have revived it).
                if let a = self.activities.first(where: { $0.id == id }), a.status == .success {
                    self.activities.removeAll { $0.id == id }
                }
                self.pruneTasks[id] = nil
            }
        }
    }

    private func cancelPrune(_ id: String) {
        pruneTasks[id]?.cancel()
        pruneTasks[id] = nil
    }
}
