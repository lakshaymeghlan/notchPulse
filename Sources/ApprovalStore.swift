import SwiftUI

/// Pending permission requests from agents (e.g. Claude Code about to run a
/// command). The hook posts a request and polls for the user's decision.
@MainActor
final class ApprovalStore: ObservableObject {
    struct Approval: Identifiable, Equatable {
        let id: String
        let tool: String
        let command: String
        let source: String
    }

    @Published private(set) var pending: [Approval] = []
    private var decisions: [String: Bool] = [:] // id → allow

    /// Fired when a request arrives or a decision is made.
    var onChange: (() -> Void)?

    func request(id: String, tool: String, command: String, source: String) {
        guard decisions[id] == nil, !pending.contains(where: { $0.id == id }) else { return }
        pending.insert(Approval(id: id, tool: tool, command: command, source: source), at: 0)
        onChange?()
    }

    func decide(_ id: String, allow: Bool) {
        decisions[id] = allow
        pending.removeAll { $0.id == id }
        onChange?()
    }

    /// nil = still pending.
    func decision(for id: String) -> Bool? { decisions[id] }
}
