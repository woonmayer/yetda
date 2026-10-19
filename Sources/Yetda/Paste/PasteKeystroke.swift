import Carbon.HIToolbox
import CoreGraphics
import YetdaCore

/// Posts a synthetic paste keystroke (⌃V or ⌘V) to the frontmost app.
@MainActor
enum PasteKeystroke {
    /// Presses and releases the modifier around V, like a real keyboard;
    /// some terminals ignore a V that only carries the modifier flag.
    static func send(_ key: PasteTarget.PasteKey) {
        let (modifier, flag): (Int, CGEventFlags) = key == .commandV
            ? (kVK_Command, .maskCommand)
            : (kVK_Control, .maskControl)
        let source = CGEventSource(stateID: .hidSystemState)
        let v = vKeyCode(for: key)
        let sequence: [(CGKeyCode, Bool, CGEventFlags)] = [
            (CGKeyCode(modifier), true, flag),
            (v, true, flag),
            (v, false, flag),
            (CGKeyCode(modifier), false, []),
        ]
        for (keyCode, keyDown, flags) in sequence {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// The key code that types "v" in the current keyboard layout, so pasting
    /// works on Dvorak, Colemak, AZERTY, etc. (`kVK_ANSI_V` is a physical
    /// position). Layouts that switch to QWERTY while ⌘ is held keep the
    /// QWERTY position for ⌘V. Falls back to `kVK_ANSI_V`.
    private static func vKeyCode(for key: PasteTarget.PasteKey) -> CGKeyCode {
        let fallback = CGKeyCode(kVK_ANSI_V)
        guard let layoutSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return fallback
        }
        if key == .commandV, let idPointer = TISGetInputSourceProperty(layoutSource, kTISPropertyInputSourceID) {
            let id = Unmanaged<CFString>.fromOpaque(idPointer).takeUnretainedValue() as String
            if id.hasSuffix("QWERTYCMD") { return fallback }
        }
        guard let dataPointer = TISGetInputSourceProperty(layoutSource, kTISPropertyUnicodeKeyLayoutData) else {
            return fallback
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { raw -> CGKeyCode in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return fallback }
            for code in UInt16(0)..<128 {
                var deadKeyState: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars
                )
                if status == noErr, length == 1, chars[0] == UniChar(UInt8(ascii: "v")) {
                    return CGKeyCode(code)
                }
            }
            return fallback
        }
    }
}
