import Carbon.HIToolbox

/// Global ⌃⌘V. Carbon hotkeys need no Accessibility permission.
@MainActor
enum HotKey {
    private static var action: (() -> Void)?
    private static var ref: EventHotKeyRef?

    /// False when registration failed, for example when another app holds ⌃⌘V.
    private(set) static var isRegistered = false

    static func register(_ action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handler: EventHandlerRef?
        guard InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, &handler) == noErr else { return }
        let id = EventHotKeyID(signature: OSType(0x4F53_434C), id: 1) // "OSCL"
        isRegistered = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | controlKey), id,
                                           GetApplicationEventTarget(), 0, &ref) == noErr
        if !isRegistered { RemoveEventHandler(handler) }
    }
}
