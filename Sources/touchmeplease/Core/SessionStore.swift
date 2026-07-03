import Foundation
import Combine

/// Observable source of truth for the floating window.
/// Merges `SessionScanner` (metadata) with `TranscriptReader` (run-state),
/// refreshing on filesystem changes (debounced) plus a periodic safety timer.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionInfo] = []

    var waitingCount: Int { sessions.filter { $0.state == .waiting }.count }

    /// Waiting sessions the user hasn't tapped since their latest activity.
    var unvisitedCount: Int {
        sessions.filter {
            $0.state == .waiting
                && acks.isUnvisited(cliSessionId: $0.cliSessionId, lastActivityAt: $0.lastActivityAt)
        }.count
    }

    /// True for a waiting row that should show the blue "not yet visited" highlight.
    func isUnvisited(_ session: SessionInfo) -> Bool {
        session.state == .waiting
            && acks.isUnvisited(cliSessionId: session.cliSessionId, lastActivityAt: session.lastActivityAt)
    }

    /// Marks a row visited (clears its blue highlight) when the user taps it.
    func acknowledge(_ session: SessionInfo) {
        acks.acknowledge(cliSessionId: session.cliSessionId, lastActivityAt: session.lastActivityAt)
        objectWillChange.send()
    }

    /// Temporarily removes a row from the list (the X button). Not a delete:
    /// the row reappears if the chat gets newer activity, or on app restart.
    func hide(_ session: SessionInfo) {
        hides.hide(cliSessionId: session.cliSessionId, lastActivityAt: session.lastActivityAt)
        sessions = sessions.filter { $0.cliSessionId != session.cliSessionId }
    }

    private let acks = AcknowledgmentStore()
    private let hides = HiddenStore()
    private var watcher: DirectoryWatcher?
    private var timer: Timer?
    private var debounce: DispatchWorkItem?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        watcher = DirectoryWatcher(
            paths: [SessionScanner.sessionsRoot.path, TranscriptReader.projectsRoot.path]
        ) { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        watcher = nil
    }

    private func scheduleRefresh() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func refresh() {
        // Scan + derive off the main actor, publish back on it.
        Task.detached(priority: .utility) {
            let scanned = SessionScanner.scan()
            let derived = scanned
                .map { $0.withState(TranscriptReader.state(forCliSessionId: $0.cliSessionId)) }
                .sorted { lhs, rhs in
                    lhs.state.sortRank != rhs.state.sortRank
                        ? lhs.state.sortRank < rhs.state.sortRank
                        : lhs.lastActivityAt > rhs.lastActivityAt
                }
            let liveIds = Set(derived.map(\.cliSessionId))
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.acks.prune(keeping: liveIds)
                self.hides.prune(keeping: liveIds)
                // Drop rows the user hid (unless newer activity brought them back).
                let visible = derived.filter {
                    !self.hides.isHidden(cliSessionId: $0.cliSessionId, lastActivityAt: $0.lastActivityAt)
                }
                if self.sessions != visible { self.sessions = visible }
            }
        }
    }
}
