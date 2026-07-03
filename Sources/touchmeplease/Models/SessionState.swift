import Foundation

/// Derived run-state of a chat session.
enum SessionState: String, Sendable {
    /// Assistant finished its turn and is waiting on the user (last event = assistant end_turn).
    case waiting
    /// Assistant is mid-work (last event = tool_use, or a trailing user/tool_result).
    case working
    /// No transcript activity could be read, or nothing conclusive.
    case idle

    /// Sort priority for the list: working (amber) on top, then waiting (red),
    /// then idle (grey). Lower rank sorts higher.
    var sortRank: Int {
        switch self {
        case .working: return 0
        case .waiting: return 1
        case .idle: return 2
        }
    }
}
