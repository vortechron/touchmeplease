import Foundation

/// Persists which waiting sessions the user has already visited (tapped).
///
/// A session is "unvisited" (deserves the blue highlight) when it is `.waiting`
/// and either was never acknowledged, or has had *newer* activity since it was
/// last acknowledged — the latter covers a working→waiting re-transition, which
/// makes the row fresh again.
///
/// Keyed by `cliSessionId`; the stored value is the `lastActivityAt` (epoch ms)
/// at the moment of acknowledgment. Persisted as JSON under Application Support
/// so visited state survives app restarts.
final class AcknowledgmentStore: @unchecked Sendable {
    private var acked: [String: Double] = [:]   // cliSessionId → ackedActivityMs
    private let lock = NSLock()
    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("touchmeplease", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("acknowledged.json")
        load()
    }

    /// True when this waiting session has fresh activity the user hasn't tapped yet.
    func isUnvisited(cliSessionId: String, lastActivityAt: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let ackedMs = acked[cliSessionId] else { return true }
        return lastActivityAt.timeIntervalSince1970 * 1000 > ackedMs + 1   // +1ms slack
    }

    /// Marks a session visited as of its current activity timestamp.
    func acknowledge(cliSessionId: String, lastActivityAt: Date) {
        lock.lock()
        acked[cliSessionId] = lastActivityAt.timeIntervalSince1970 * 1000
        lock.unlock()
        save()
    }

    /// Drops entries for sessions that no longer exist, keeping the file small.
    func prune(keeping liveIds: Set<String>) {
        lock.lock()
        let before = acked.count
        acked = acked.filter { liveIds.contains($0.key) }
        let changed = acked.count != before
        lock.unlock()
        if changed { save() }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return }
        lock.lock(); acked = map; lock.unlock()
    }

    private func save() {
        lock.lock(); let snapshot = acked; lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
