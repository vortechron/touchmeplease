import Foundation

/// Immutable snapshot of one Claude.app desktop chat session.
struct SessionInfo: Identifiable, Sendable, Equatable {
    let id: String            // desktop sessionId (e.g. local_<uuid>)
    let cliSessionId: String  // UUID used for claude://resume and transcript filename
    let title: String
    let cwd: String
    let lastActivityAt: Date
    let isArchived: Bool
    let state: SessionState

    /// Basename of the working directory, for compact display.
    var projectName: String {
        let base = (cwd as NSString).lastPathComponent
        return base.isEmpty ? cwd : base
    }

    /// Fallback display name for an untitled chat: "<project> (untitled)".
    func titledByProject() -> SessionInfo {
        let name = projectName.isEmpty ? "Untitled" : "\(projectName) (untitled)"
        return SessionInfo(
            id: id, cliSessionId: cliSessionId, title: name, cwd: cwd,
            lastActivityAt: lastActivityAt, isArchived: isArchived, state: state
        )
    }

    /// Returns a copy with a freshly-derived state. (Immutable update.)
    func withState(_ newState: SessionState) -> SessionInfo {
        SessionInfo(
            id: id,
            cliSessionId: cliSessionId,
            title: title,
            cwd: cwd,
            lastActivityAt: lastActivityAt,
            isArchived: isArchived,
            state: newState
        )
    }
}
