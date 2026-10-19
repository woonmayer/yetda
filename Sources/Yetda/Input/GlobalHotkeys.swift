import Carbon.HIToolbox

/// Global hotkeys via Carbon's `RegisterEventHotKey`, which (unlike an event
/// tap) needs no Accessibility permission. Actions run on the main actor.
@MainActor
enum GlobalHotkeys {
    private static let signature = OSType(0x5954_4441) // 'YTDA'
    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var hotKeyRefs: [EventHotKeyRef] = []
    private static var isHandlerInstalled = false

    /// Returns false if the hotkey could not be registered (e.g. another app
    /// already uses the combination).
    @discardableResult
    static func register(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) -> Bool {
        guard installHandlerIfNeeded() else { return false }
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRefs.append(ref)
        actions[id] = action
        return true
    }

    fileprivate static func fire(_ id: UInt32) {
        actions[id]?()
    }

    private static func installHandlerIfNeeded() -> Bool {
        guard !isHandlerInstalled else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), handleHotKeyEvent, 1, &eventType, nil, nil)
        isHandlerInstalled = status == noErr
        return isHandlerInstalled
    }
}

/// Carbon delivers hotkey events on the main thread.
private func handleHotKeyEvent(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated { GlobalHotkeys.fire(id) }
    return noErr
}
