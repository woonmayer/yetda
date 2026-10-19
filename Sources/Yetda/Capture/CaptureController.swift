import Foundation
import YetdaCore

/// The capture pipeline: run the selection into a pending file, scan it
/// (mask secrets, read its text) if enabled, move it into the capture
/// folder, put it on the clipboard, and auto-paste it.
@MainActor
final class CaptureController {
    /// How long the unmasked original of the last capture stays available.
    private static let unmaskLifetime: Duration = .seconds(300)

    var onCapturesChanged: (() -> Void)?
    /// The capture folder had to be recreated (the user deleted it).
    var onFolderRecreated: (() -> Void)?
    /// A short status for the menu bar, e.g. "🔒 2".
    var onStatus: ((String) -> Void)?

    private let store: CaptureStore
    private let service = CaptureService(run: runScreencapture)
    private let autoPaster: AutoPaster
    private var isCapturing = false

    /// The newest capture as taken, before secrets were masked. Memory only;
    /// dropped after `unmaskLifetime` or when the next capture is taken.
    private var unmasked: Data?
    private var unmaskExpiry: Task<Void, Never>?

    init(store: CaptureStore, autoPaster: AutoPaster) {
        self.store = store
        self.autoPaster = autoPaster
    }

    var hasUnmasked: Bool { unmasked != nil }

    func capture() {
        guard !isCapturing else { return } // one selection overlay at a time
        if !Permissions.hasScreenRecording {
            // Capture anyway (the grant may only apply after a relaunch), but
            // make sure the user has been asked; the menu shows a warning too.
            Permissions.requestScreenRecording()
        }
        guard prepareFolder() else { return }
        isCapturing = true
        let date = Date()
        let pending = store.pendingFileURL(for: date)
        let final = store.fileURL(for: date)
        let service = service
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                service.capture(toFile: pending.path)
            }.value
            isCapturing = false
            switch outcome {
            case .cancelled: return
            case .failed: onStatus?("⚠︎ capture failed")
            case .captured: await finish(pending: pending, final: final)
            }
        }
    }

    /// Re-delivers an earlier capture (Paste Recent). It was scanned when
    /// taken; scanning again also covers captures from before masking was on.
    func deliver(_ url: URL) {
        Task {
            guard let text = await scan(url, keepOriginal: false) else { return }
            copyAndPaste(url, text: text)
        }
    }

    func pasteUnmasked() {
        guard let png = unmasked else { return }
        Clipboard.setPNG(png)
        if Settings.autoPaste { autoPaster.paste() }
    }

    // MARK: - Steps

    private func finish(pending: URL, final: URL) async {
        keepUnmasked(nil) // whatever happens, the previous original is stale now
        guard let text = await scan(pending, keepOriginal: true) else {
            discard(pending)
            return
        }
        do {
            try FileManager.default.moveItem(at: pending, to: final)
        } catch {
            NSLog("Yetda: could not move the capture into \(store.folderURL.path): \(error.localizedDescription)")
            onStatus?("⚠︎ not saved")
            discard(pending)
            return
        }
        copyAndPaste(final, text: text)
        store.prune()
        onCapturesChanged?()
    }

    /// Masks and reads `url` as the settings ask. Returns the text to paste
    /// after the image ("" for none), or nil if the capture must not be
    /// shared because masking failed.
    private func scan(_ url: URL, keepOriginal: Bool) async -> String? {
        let redact = Settings.redactSecrets
        let wantText = Settings.autoPaste && Settings.pasteText
        guard redact || wantText else { return "" }
        let scan = await ScreenshotScanner.scan(url, redact: redact)
        if scan.maskingFailed {
            onStatus?("⚠︎ not pasted")
            return nil
        }
        if keepOriginal { keepUnmasked(scan.original) }
        if scan.hiddenCount > 0 { onStatus?("🔒 \(scan.hiddenCount)") }
        return wantText ? ScreenshotText.promptBlock(scan.text) ?? "" : ""
    }

    private func copyAndPaste(_ url: URL, text: String) {
        guard let png = try? Data(contentsOf: url) else {
            NSLog("Yetda: could not read \(url.lastPathComponent) for the clipboard.")
            onStatus?("⚠︎ not copied")
            return
        }
        Clipboard.setPNG(png)
        guard Settings.autoPaste else { return }
        autoPaster.paste(followedBy: text.isEmpty ? nil : text) { Clipboard.setPNG(png) }
    }

    /// Creates the capture folder if needed. False (with a status) if it can't be.
    private func prepareFolder() -> Bool {
        let existed = FileManager.default.fileExists(atPath: store.folderURL.path)
        do {
            try store.createFolder()
        } catch {
            NSLog("Yetda: could not create \(store.folderURL.path): \(error.localizedDescription)")
            onStatus?("⚠︎ no folder")
            return false
        }
        if !existed { onFolderRecreated?() }
        return true
    }

    private func discard(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("Yetda: could not delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func keepUnmasked(_ png: Data?) {
        unmaskExpiry?.cancel()
        unmasked = png
        guard png != nil else { return }
        unmaskExpiry = Task { [weak self] in
            try? await Task.sleep(for: Self.unmaskLifetime)
            guard !Task.isCancelled else { return }
            self?.unmasked = nil
        }
    }
}
