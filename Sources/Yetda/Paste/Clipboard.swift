import AppKit

/// The general pasteboard, holding either a capture or its text.
@MainActor
enum Clipboard {
    static func setPNG(_ png: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
    }

    static func setText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
