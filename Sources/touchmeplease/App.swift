import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private let store = SessionStore()
    private var toggleHotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a UI agent: no Dock icon, no menu bar app switching.
        NSApp.setActivationPolicy(.accessory)

        store.start()

        let hosting = NSHostingView(rootView: ContentView(store: store))
        // Let SwiftUI's content size drive the window size, so collapsing the
        // list actually shrinks the panel (and expanding grows it back).
        hosting.sizingOptions = [.preferredContentSize]

        let panel = FloatingPanel(content: hosting)
        panel.orderFrontRegardless()
        self.panel = panel

        // ⌘⌥H toggles the panel's visibility from anywhere.
        toggleHotKey = HotKey(
            keyCode: UInt32(kVK_ANSI_H),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}

@main
enum Main {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
