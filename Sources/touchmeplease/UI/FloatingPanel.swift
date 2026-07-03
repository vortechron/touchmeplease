import AppKit
import SwiftUI

/// Borderless, translucent, always-on-top panel that floats over all Spaces and
/// fullscreen apps without stealing focus. Draggable by its background.
final class FloatingPanel: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        contentView = content
        setFrameAutosaveName("touchmeplease.panel")  // remembers position

        if frame.origin == .zero {
            positionTopRight()
        }
    }

    /// Keep the top edge fixed across content-driven resizes.
    override func setContentSize(_ size: NSSize) {
        let top = frame.maxY
        super.setContentSize(size)
        var f = frame
        f.origin.y = top - f.height
        setFrameOrigin(f.origin)
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        setFrameOrigin(NSPoint(
            x: visible.maxX - frame.width - margin,
            y: visible.maxY - frame.height - margin
        ))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
