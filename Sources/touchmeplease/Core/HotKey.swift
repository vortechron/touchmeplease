import AppKit
import Carbon.HIToolbox

/// A single system-wide hotkey registered via Carbon's `RegisterEventHotKey`.
/// This fires even when the app is an `LSUIElement` accessory that never
/// becomes active, and — unlike `NSEvent.addGlobalMonitorForEvents` — it needs
/// no Accessibility permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onFire: () -> Void

    /// - Parameters:
    ///   - keyCode: a Carbon virtual key code (e.g. `kVK_ANSI_H`).
    ///   - modifiers: Carbon modifier mask (e.g. `cmdKey | optionKey`).
    init(keyCode: UInt32, modifiers: UInt32, onFire: @escaping () -> Void) {
        self.onFire = onFire

        let id = EventHotKeyID(signature: OSType(0x544D_5048 /* "TMPH" */), id: 1)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var firedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.onFire()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handler
        )

        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
