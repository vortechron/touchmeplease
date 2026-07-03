import Foundation

/// Tracks sessions the user has *temporarily* dismissed from the list (the row X).
///
/// This is deliberately **in-memory only** — no file, no caching layer:
///   - Hiding is a "clear it out of my way for now" gesture, not a delete.
///   - A hidden row auto-reappears the moment the chat sees *newer* activity
///     (i.e. the conversation continued), so "resume later" surfaces it again.
///   - Quitting the app forgets all hides — everything comes back on next launch.
///
/// Keyed by `cliSessionId`; the stored value is the `lastActivityAt` (epoch ms)
/// at the moment of hiding. Mirrors `AcknowledgmentStore`'s freshness check.
final class HiddenStore: @unchecked Sendable {
    private var hidden: [String: Double] = [:]   // cliSessionId → hiddenAtActivityMs
    private let lock = NSLock()

    /// Hides a session as of its current activity timestamp.
    func hide(cliSessionId: String, lastActivityAt: Date) {
        lock.lock()
        hidden[cliSessionId] = lastActivityAt.timeIntervalSince1970 * 1000
        lock.unlock()
    }

    /// True while this session should stay hidden — i.e. it was hidden and has
    /// had no newer activity since. Fresh activity auto-unhides it.
    func isHidden(cliSessionId: String, lastActivityAt: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let hiddenMs = hidden[cliSessionId] else { return false }
        return lastActivityAt.timeIntervalSince1970 * 1000 <= hiddenMs + 1   // +1ms slack
    }

    /// Drops entries for sessions that no longer exist, keeping the map small.
    func prune(keeping liveIds: Set<String>) {
        lock.lock()
        hidden = hidden.filter { liveIds.contains($0.key) }
        lock.unlock()
    }
}
