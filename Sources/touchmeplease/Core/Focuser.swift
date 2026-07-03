import AppKit

/// Brings Claude.app to the front. We intentionally do NOT deep-link to a specific
/// chat: the only link that reaches a local Code-tab chat (`claude://resume`) forks a
/// duplicate session, and the clean focus primitive is origin-gated to Claude's own
/// renderer (unreachable externally). So tapping just raises the app; the user picks
/// the row, which the notifier makes easy by mirroring the app's session list.
enum Focuser {
    private static let claudeBundleId = "com.anthropic.claudefordesktop"

    static func bringForward() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: claudeBundleId)
        if let claude = apps.first {
            claude.activate(options: [.activateAllWindows])
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        }
    }
}
