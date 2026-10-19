import AppKit
import ImageIO
import YetdaCore

/// The "Paste Recent" list: the newest captures with thumbnails and relative
/// times. Items 1–9 get number shortcuts; picking one calls `onPick`. Used
/// both as a submenu (filled only when opened) and as the ⌘⇧1 pop-up.
@MainActor
final class RecentCapturesMenu: NSObject, NSMenuDelegate {
    private static let limit = 10
    private static let thumbnailHeight: CGFloat = 36

    let submenu = NSMenu()
    private let store: CaptureStore
    private let onPick: @MainActor (URL) -> Void

    init(store: CaptureStore, onPick: @escaping @MainActor (URL) -> Void) {
        self.store = store
        self.onPick = onPick
        super.init()
        submenu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        fill(menu)
    }

    /// Pops the list up at the mouse pointer. Returns whether an item was picked.
    func popUpAtMouse() -> Bool {
        let menu = NSMenu()
        fill(menu)
        NSApp.activate(ignoringOtherApps: true) // so arrow and number keys reach the menu
        return menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = store.captureFiles().prefix(Self.limit)
        guard !urls.isEmpty else {
            let empty = NSMenuItem(title: "No captures", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let now = Date()
        for (index, url) in urls.enumerated() {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? now
            let item = NSMenuItem(
                title: formatter.localizedString(for: modified, relativeTo: now),
                action: #selector(picked(_:)),
                keyEquivalent: index < 9 ? String(index + 1) : ""
            )
            item.keyEquivalentModifierMask = []
            item.target = self
            item.representedObject = url
            item.image = Self.thumbnail(for: url)
            menu.addItem(item)
        }
    }

    @objc private func picked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onPick(url)
    }

    /// A downsampled thumbnail, so opening the menu doesn't decode ten
    /// full-resolution captures.
    private static func thumbnail(for url: URL) -> NSImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailHeight * 3 * 2, // up to 3:1, @2x
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
              image.height > 0 else { return nil }
        let height = thumbnailHeight
        let width = min(CGFloat(image.width) * height / CGFloat(image.height), height * 3)
        return NSImage(cgImage: image, size: NSSize(width: width, height: height))
    }
}
