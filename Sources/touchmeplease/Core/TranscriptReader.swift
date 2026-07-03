import Foundation

/// Reads a CLI transcript (`<cliSessionId>.jsonl`) and derives the session's run-state.
///
/// Rule (verified against live transcripts + decompiled app):
///   - Consider only lines carrying a `timestamp` (skip meta lines: title/ai-title/last-prompt).
///   - Look at the LAST such line:
///       * type == "assistant" && message.stop_reason == "end_turn"  → .waiting
///       * type == "assistant" && message.stop_reason == "tool_use"  → .working
///       * type == "user" (tool_result / queued prompt)              → .working
///   - Anything else / unreadable → .idle
enum TranscriptReader {

    static let projectsRoot: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }()

    /// Caches cliSessionId → transcript URL so we don't re-glob every poll.
    private static let cache = TranscriptPathCache()

    static func state(forCliSessionId cliId: String) -> SessionState {
        guard let url = cache.url(for: cliId) else { return .idle }
        guard let tail = readTail(url, maxBytes: 64 * 1024) else { return .idle }
        return deriveState(fromTail: tail)
    }

    // MARK: - Tail reading

    /// Reads up to `maxBytes` from the end of the file as a UTF-8 string.
    private static func readTail(_ url: URL, maxBytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let end = try? handle.seekToEnd() else { return nil }
        let start = end > UInt64(maxBytes) ? end - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - State derivation

    static func deriveState(fromTail tail: String) -> SessionState {
        // Walk lines from the bottom; the first that has a timestamp decides.
        let lines = tail.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            guard obj["timestamp"] != nil else { continue }   // skip meta lines

            let type = obj["type"] as? String
            let message = obj["message"] as? [String: Any]
            let stop = message?["stop_reason"] as? String

            switch type {
            case "assistant":
                return stop == "end_turn" ? .waiting : .working
            case "user":
                return .working
            default:
                return .idle
            }
        }
        return .idle
    }
}

/// Resolves and caches the transcript file for a given cliSessionId.
final class TranscriptPathCache: @unchecked Sendable {
    private var map: [String: URL] = [:]
    private let lock = NSLock()

    func url(for cliId: String) -> URL? {
        lock.lock()
        if let cached = map[cliId], FileManager.default.fileExists(atPath: cached.path) {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let found = locate(cliId) else { return nil }
        lock.lock(); map[cliId] = found; lock.unlock()
        return found
    }

    /// Globs `<root>/*/<cliId>.jsonl` across all project directories.
    private func locate(_ cliId: String) -> URL? {
        let fm = FileManager.default
        let root = TranscriptReader.projectsRoot
        let filename = "\(cliId).jsonl"
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }

        for dir in projectDirs {
            let candidate = dir.appendingPathComponent(filename)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}
