import Carbon

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPressed: (() -> Void)?

    func register() -> OSStatus {
        guard hotKey == nil else { return noErr }
        if handler == nil {
            var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x43545950, identifier.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { shortcut.onPressed?() }
                return noErr
            }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard result == noErr else { return result }
        }
        return RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x43545950, id: 1), GetApplicationEventTarget(), 0, &hotKey)
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    func stop() {
        unregister()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
