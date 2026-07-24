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

    struct Decision { let allow: Bool; let text: String? }

    @Published private(set) var pending: [Approval] = []
    private var decisions: [String: Decision] = [:]

    /// Fired when a request arrives or a decision is made.
    var onChange: (() -> Void)?

    func request(id: String, tool: String, command: String, source: String) {
        guard decisions[id] == nil, !pending.contains(where: { $0.id == id }) else { return }
        pending.insert(Approval(id: id, tool: tool, command: command, source: source), at: 0)
        onChange?()
    }

    /// `text` is a free-form answer the user typed (e.g. their opinion); the
    /// agent's hook can read it from /decision. Yes/No pass no text.
    func decide(_ id: String, allow: Bool, text: String? = nil) {
        decisions[id] = Decision(allow: allow, text: text)
        pending.removeAll { $0.id == id }
        onChange?()
    }

    /// nil = still pending.
    func decision(for id: String) -> Decision? { decisions[id] }
}
