import AppKit
import Carbon.HIToolbox
import YetdaCore

/// Wires the app together at launch: the menu bar item, the capture
/// pipeline, and the three triggers (⌘⇧2 capture, ⌘⇧1 recent, ⌘⌘ capture).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = CaptureStore()
    private let autoPaster = AutoPaster(
        extraTerminals: { Settings.extraTerminalBundleIDs },
        pasteKeyOverride: { Settings.pasteKeyOverride }
    )
    private lazy var captures = CaptureController(store: store, autoPaster: autoPaster)
    private lazy var statusMenu = StatusMenu(store: store, handlers: menuHandlers)
    private lazy var doubleCommand = DoubleCommandMonitor { [weak self] in self?.captures.capture() }
    private lazy var folderMonitor = CaptureFolderMonitor(url: store.folderURL) { [weak self] in
        self?.statusMenu.refreshBadge()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyMigration.run(newFolder: store.folderURL)
        store.clearPending()
        do {
            try store.createFolder()
        } catch {
            NSLog("Yetda: could not create \(store.folderURL.path): \(error.localizedDescription)")
        }
        store.prune()

        statusMenu.install()
        let flash: (String) -> Void = { [weak self] status in self?.statusMenu.flash(status) }
        captures.onStatus = flash
        autoPaster.onStatus = flash
        captures.onCapturesChanged = { [weak self] in self?.statusMenu.refreshBadge() }
        captures.onFolderRecreated = { [weak self] in
            self?.folderMonitor.stop()
            self?.folderMonitor.start()
        }
        folderMonitor.start()

        registerHotkey(kVK_ANSI_2, name: "⌘⇧2", fallback: "Capture") { [weak self] in self?.captures.capture() }
        registerHotkey(kVK_ANSI_1, name: "⌘⇧1", fallback: "Paste Recent") { [weak self] in
            self?.statusMenu.showRecentPicker()
        }
        if Settings.doubleCommandCapture { doubleCommand.start() }
        if Settings.redactSecrets || Settings.pasteText { TextRecognizer.warmUp() }

        SkillInstaller.updateInstalledCopies()
        // After launch finishes, so the question doesn't hold up the menu bar item.
        Task { SkillInstaller.offerOnce() }
    }

    private var menuHandlers: StatusMenu.Handlers {
        StatusMenu.Handlers(
            capture: { [weak self] in self?.captures.capture() },
            deliver: { [weak self] url in self?.captures.deliver(url) },
            pasteUnmasked: { [weak self] in self?.captures.pasteUnmasked() },
            hasUnmasked: { [weak self] in self?.captures.hasUnmasked ?? false },
            doubleCommandChanged: { [weak self] enabled in
                if enabled { self?.doubleCommand.start() } else { self?.doubleCommand.stop() }
            },
            terminalsChanged: { [weak self] in self?.autoPaster.noticeFrontmostApp() }
        )
    }

    private func registerHotkey(_ keyCode: Int, name: String, fallback: String, action: @escaping @MainActor () -> Void) {
        let registered = GlobalHotkeys.register(
            keyCode: UInt32(keyCode),
            modifiers: UInt32(cmdKey | shiftKey),
            action: action
        )
        if !registered {
            NSLog("Yetda: global hotkey \(name) could not be registered (already in use). Use the menu's \(fallback) item.")
        }
    }
}
