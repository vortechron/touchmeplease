import Foundation

/// Scans Claude.app's local session metadata files into `SessionInfo` values.
///
/// Layout: ~/Library/Application Support/Claude/claude-code-sessions/<workspace>/<session>/local_*.json
enum SessionScanner {

    /// Raw shape of a `local_*.json` metadata file (only the fields we need).
    private struct RawSession: Decodable {
        let sessionId: String
        let cliSessionId: String?
        let title: String?
        let cwd: String?
        let lastActivityAt: Double?   // epoch milliseconds
        let isArchived: Bool?
    }

    static let sessionsRoot: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
    }()

    /// Returns all non-archived desktop sessions, newest activity first.
    /// State is left `.idle` here; `TranscriptReader` derives the real state.
    static func scan(idleCutoff: TimeInterval = 8 * 3600,
                     now: Date = Date()) -> [SessionInfo] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // Claude.app writes TWO local_*.json per chat that share one cliSessionId:
        // a titled record + an untitled CLI-import "shadow" record (whose
        // lastActivityAt is sometimes newer). Merge them by cliSessionId.
        var byCli: [String: SessionInfo] = [:]

        for case let url as URL in walker {
            let name = url.lastPathComponent
            guard name.hasPrefix("local_"), name.hasSuffix(".json") else { continue }

            guard let session = decode(url) else { continue }
            guard !(session.isArchived ?? false) else { continue }
            guard let cli = session.cliSessionId, !cli.isEmpty else { continue }

            let lastActivity = Date(timeIntervalSince1970: (session.lastActivityAt ?? 0) / 1000)
            let title = session.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let info = SessionInfo(
                id: session.sessionId,
                cliSessionId: cli,
                title: (title?.isEmpty == false) ? title! : "",
                cwd: session.cwd ?? "",
                lastActivityAt: lastActivity,
                isArchived: false,
                state: .idle
            )

            byCli[cli] = merge(existing: byCli[cli], incoming: info)
        }

        // Drop sessions idle beyond the cutoff, fall back to project name when untitled.
        return byCli.values
            .filter { now.timeIntervalSince($0.lastActivityAt) <= idleCutoff }
            .map { $0.title.isEmpty ? $0.titledByProject() : $0 }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    /// Combines two records for the same chat. The "shadow" record (id ==
    /// `local_<cliId>`, created by a resume import) is the artifact; the original
    /// chat has a random id. We prefer the ORIGINAL's title (it's the real one the
    /// app shows), keep the most-recent activity, and prefer the original's id.
    private static func merge(existing: SessionInfo?, incoming: SessionInfo) -> SessionInfo {
        guard let existing else { return incoming }

        let cli = incoming.cliSessionId
        func isShadow(_ s: SessionInfo) -> Bool { s.id == "local_\(cli)" }

        // Prefer the non-shadow record's title; fall back to whichever has one.
        let preferred = isShadow(existing) ? incoming : existing
        let other = isShadow(existing) ? existing : incoming
        let title = !preferred.title.isEmpty ? preferred.title
                  : (!other.title.isEmpty ? other.title : "")

        let newest = existing.lastActivityAt >= incoming.lastActivityAt ? existing : incoming
        let idSource = !preferred.id.isEmpty ? preferred : other
        return SessionInfo(
            id: idSource.id,
            cliSessionId: cli,
            title: title,
            cwd: existing.cwd.isEmpty ? incoming.cwd : existing.cwd,
            lastActivityAt: newest.lastActivityAt,
            isArchived: false,
            state: .idle
        )
    }

    private static func decode(_ url: URL) -> RawSession? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RawSession.self, from: data)
        } catch {
            // A malformed/partial file is skipped rather than crashing the scan.
            return nil
        }
    }
}
