import AppKit
import YetdaCore

/// Remembers the most recently active terminal and, after a capture, brings
/// it to the front and presses its paste key so the image lands in the
/// coding agent's prompt. Sending keystrokes needs Accessibility permission;
/// without it the capture just stays on the clipboard. Lives for the app's
/// lifetime, so its workspace observer is never removed.
@MainActor
final class AutoPaster {
    private enum Timing {
        /// Polls for the terminal to come to the front, up to `focusAttempts` times.
        static let focusPoll: Duration = .milliseconds(50)
        static let focusAttempts = 20
        /// After it's frontmost, so the window has key focus, not just the app.
        static let settle: Duration = .milliseconds(50)
        /// Lets the agent read the image off the clipboard before it's replaced by text.
        static let imageRead: Duration = .milliseconds(700)
        /// Lets the terminal read the text before the image goes back on the clipboard.
        static let textRead: Duration = .milliseconds(500)
    }

    /// A short status for the menu bar when a paste doesn't happen.
    var onStatus: ((String) -> Void)?

    private var lastTerminal: NSRunningApplication?
    private var hasPrompted = false
    private var activationObserver: NSObjectProtocol?
    private let extraTerminals: () -> Set<String>
    private let pasteKeyOverride: () -> PasteTarget.PasteKey?

    init(extraTerminals: @escaping () -> Set<String>, pasteKeyOverride: @escaping () -> PasteTarget.PasteKey?) {
        self.extraTerminals = extraTerminals
        self.pasteKeyOverride = pasteKeyOverride
        let workspace = NSWorkspace.shared
        lastTerminal = isTerminal(workspace.frontmostApplication)
            ? workspace.frontmostApplication
            : workspace.runningApplications.first { isTerminal($0) }
        activationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, self.isTerminal(app) else { return }
                self.lastTerminal = app
            }
        }
    }

    /// Re-checks the frontmost app, e.g. right after the user adds it as a
    /// target (it won't send another activation notification until refocused).
    func noticeFrontmostApp() {
        let app = NSWorkspace.shared.frontmostApplication
        if isTerminal(app) { lastTerminal = app }
    }

    /// Pastes the clipboard's image into the last terminal. With `text`, also
    /// pastes it right after (as a normal ⌘V text paste), then calls
    /// `restoreImage` to put the image back on the clipboard.
    func paste(followedBy text: String? = nil, restoreImage: @escaping @MainActor () -> Void = {}) {
        // Prompt at most once per launch; after that, skip quietly (the menu
        // shows the missing permission) instead of nagging on every capture.
        let trusted = Permissions.hasAccessibility(prompt: !hasPrompted)
        hasPrompted = true
        guard trusted else {
            NSLog("Yetda: auto-paste skipped, Accessibility not granted.")
            onStatus?("📋 copied")
            return
        }
        guard let terminal = lastTerminal, !terminal.isTerminated else {
            NSLog("Yetda: auto-paste skipped, no terminal has been active yet.")
            onStatus?("📋 copied")
            return
        }
        let key = PasteTarget.pasteKey(bundleID: terminal.bundleIdentifier, override: pasteKeyOverride())
        terminal.activate()
        Task {
            // Only press keys once the terminal really is in front, so they
            // never land in whatever app happened to be there.
            guard await waitUntilFrontmost(terminal) else {
                NSLog("Yetda: the terminal didn't come to the front; capture left on the clipboard.")
                onStatus?("📋 copied")
                return
            }
            try? await Task.sleep(for: Timing.settle)
            PasteKeystroke.send(key)
            guard let text else { return }
            try? await Task.sleep(for: Timing.imageRead)
            Clipboard.setText(text)
            PasteKeystroke.send(.commandV)
            try? await Task.sleep(for: Timing.textRead)
            restoreImage()
        }
    }

    private func waitUntilFrontmost(_ app: NSRunningApplication) async -> Bool {
        for _ in 0..<Timing.focusAttempts {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { return true }
            try? await Task.sleep(for: Timing.focusPoll)
        }
        return false
    }

    private func isTerminal(_ app: NSRunningApplication?) -> Bool {
        PasteTarget.isTerminal(bundleID: app?.bundleIdentifier, extra: extraTerminals())
    }
}
