import AppKit
import YetdaCore

/// The menu bar item: its badge (pending captures), its menu, and the
/// settings toggles in it. What the actions do is up to `Handlers`.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    struct Handlers {
        var capture: @MainActor () -> Void
        var deliver: @MainActor (URL) -> Void
        var pasteUnmasked: @MainActor () -> Void
        var hasUnmasked: @MainActor () -> Bool
        var doubleCommandChanged: @MainActor (Bool) -> Void
        var terminalsChanged: @MainActor () -> Void
    }

    private static let flashDuration: Duration = .seconds(3)
    private static let pasteKeyChoices: [(title: String, key: PasteTarget.PasteKey?)] = [
        ("Automatic (⌃V; ⌘V in iTerm2 and agent apps)", nil),
        ("⌃V", .controlV),
        ("⌘V (e.g. Cursor CLI)", .commandV),
    ]

    private let store: CaptureStore
    private let handlers: Handlers
    private lazy var recentMenu = RecentCapturesMenu(store: store) { [handlers] url in handlers.deliver(url) }
    private var statusItem: NSStatusItem?
    private var flashReset: Task<Void, Never>?

    // Items refreshed each time the menu opens.
    private let screenRecordingWarning = NSMenuItem()
    private let accessibilityWarning = NSMenuItem()
    private let unmaskItem = NSMenuItem()
    private let clearItem = NSMenuItem()
    private let autoPasteItem = NSMenuItem()
    private let frontAppItem = NSMenuItem()
    private var frontAppBundleID: String?
    private var pasteKeyItems: [NSMenuItem] = []
    private let doubleCommandItem = NSMenuItem()
    private let redactItem = NSMenuItem()
    private let pasteTextItem = NSMenuItem()
    private let skillItem = NSMenuItem()

    init(store: CaptureStore, handlers: Handlers) {
        self.store = store
        self.handlers = handlers
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Yetda")
        item.button?.imagePosition = .imageLeading
        item.menu = buildMenu()
        statusItem = item
        refreshBadge()
    }

    /// Shows how many captures are pending next to the icon.
    func refreshBadge() {
        guard flashReset == nil else { return } // a flash is showing; it refreshes when done
        let count = store.captureFiles().count
        statusItem?.button?.title = count > 0 ? " \(count)" : ""
    }

    /// Shows `status` next to the icon for a moment, then the badge again.
    func flash(_ status: String) {
        flashReset?.cancel()
        statusItem?.button?.title = " \(status)"
        flashReset = Task { [weak self] in
            try? await Task.sleep(for: Self.flashDuration)
            guard !Task.isCancelled, let self else { return }
            self.flashReset = nil
            self.refreshBadge()
        }
    }

    func showRecentPicker() {
        let picked = recentMenu.popUpAtMouse()
        // Nothing picked, or auto-paste won't move focus on: hand focus back.
        if !picked || !Settings.autoPaste { NSApp.hide(nil) }
    }

    // MARK: - Building

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        configure(screenRecordingWarning, "⚠︎ Grant Screen Recording…", #selector(openScreenRecordingSettings), in: menu)
        configure(accessibilityWarning, "⚠︎ Grant Accessibility…", #selector(openAccessibilitySettings), in: menu)

        let capture = configure(NSMenuItem(), "Capture", #selector(capture), in: menu)
        capture.keyEquivalent = "2"
        capture.keyEquivalentModifierMask = [.command, .shift]
        configure(NSMenuItem(), "Paste Recent", nil, in: menu).submenu = recentMenu.submenu
        configure(unmaskItem, "Paste Last Capture Without Hiding", #selector(pasteUnmasked), in: menu)
        configure(NSMenuItem(), "Open Folder", #selector(openFolder), in: menu)
        configure(clearItem, "Clear", #selector(clearAll), in: menu)

        menu.addItem(.separator())
        configure(autoPasteItem, "Auto-paste into Terminal or Agent App", #selector(toggleAutoPaste), in: menu)
        configure(frontAppItem, "", #selector(toggleFrontAppAsTerminal), in: menu).indentationLevel = 1
        configure(NSMenuItem(), "Paste Key", nil, in: menu).submenu = buildPasteKeyMenu()
        configure(doubleCommandItem, "Capture with ⌘⌘", #selector(toggleDoubleCommand), in: menu)
        configure(redactItem, "Hide Secrets in Captures", #selector(toggleRedact), in: menu)
        configure(pasteTextItem, "Also Paste Text from Capture", #selector(togglePasteText), in: menu)
        configure(skillItem, "/shots Skill", nil, in: menu).submenu = NSMenu()

        menu.addItem(.separator())
        configure(NSMenuItem(), "Support Yetda…", #selector(openSponsors), in: menu)
        menu.addItem(withTitle: "Quit Yetda", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func buildPasteKeyMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        pasteKeyItems = Self.pasteKeyChoices.enumerated().map { index, choice in
            let item = configure(NSMenuItem(), choice.title, #selector(choosePasteKey(_:)), in: menu)
            item.tag = index
            return item
        }
        return menu
    }

    @discardableResult
    private func configure(_ item: NSMenuItem, _ title: String, _ action: Selector?, in menu: NSMenu) -> NSMenuItem {
        item.title = title
        item.action = action
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Refreshing

    func menuNeedsUpdate(_ menu: NSMenu) {
        let count = store.captureFiles().count
        clearItem.title = "Clear (\(count))"
        clearItem.isEnabled = count > 0
        unmaskItem.isHidden = !handlers.hasUnmasked()

        autoPasteItem.state = .init(Settings.autoPaste)
        refreshFrontAppItem()
        for item in pasteKeyItems {
            item.state = .init(Self.pasteKeyChoices[item.tag].key == Settings.pasteKeyOverride)
        }
        doubleCommandItem.state = .init(Settings.doubleCommandCapture)
        redactItem.state = .init(Settings.redactSecrets)
        pasteTextItem.state = .init(Settings.pasteText)
        pasteTextItem.isEnabled = Settings.autoPaste

        refreshSkillMenu()

        screenRecordingWarning.isHidden = Permissions.hasScreenRecording
        let needsAccessibility = Settings.autoPaste || Settings.doubleCommandCapture
        accessibilityWarning.isHidden = !needsAccessibility || Permissions.hasAccessibility()
    }

    /// "Also Paste into <app>": offers the app the user was just in (opening
    /// a menu bar menu doesn't change the frontmost app) as an auto-paste
    /// target, unless it's already a known target or Yetda itself.
    private func refreshFrontAppItem() {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier
        frontAppBundleID = bundleID
        frontAppItem.isHidden = bundleID == nil || bundleID == Bundle.main.bundleIdentifier
            || PasteTarget.isPasteTarget(bundleID: bundleID)
        frontAppItem.title = "Also Paste into “\(app?.localizedName ?? "this app")”"
        frontAppItem.state = .init(bundleID.map(Settings.extraTerminalBundleIDs.contains) ?? false)
    }

    /// One item per agent found on this Mac: ticked when the skill is
    /// installed there; a copy the user edited is shown but can't be toggled.
    private func refreshSkillMenu() {
        let agents = SkillInstaller.presentAgents
        skillItem.isHidden = agents.isEmpty
        guard let submenu = skillItem.submenu else { return }
        submenu.removeAllItems()
        submenu.autoenablesItems = false
        for (index, agent) in agents.enumerated() {
            let state = SkillInstaller.state(of: agent)
            let edited = state == .modified
            let item = configure(
                NSMenuItem(), edited ? "\(agent.name) (edited, left as is)" : agent.name,
                #selector(toggleSkill(_:)), in: submenu
            )
            item.tag = index
            item.state = edited ? .mixed : .init(state.isInstalled)
            item.isEnabled = !edited
        }
    }

    // MARK: - Actions

    @objc private func capture() { handlers.capture() }
    @objc private func pasteUnmasked() { handlers.pasteUnmasked() }
    @objc private func openFolder() { NSWorkspace.shared.open(store.folderURL) }
    /// Opens the sponsor page in the browser; Yetda itself makes no network request.
    @objc private func openSponsors() {
        if let url = URL(string: "https://github.com/sponsors/woonmayer") { NSWorkspace.shared.open(url) }
    }
    @objc private func openScreenRecordingSettings() { Permissions.openScreenRecordingSettings() }
    @objc private func openAccessibilitySettings() { Permissions.openAccessibilitySettings() }
    @objc private func toggleRedact() { Settings.redactSecrets.toggle() }
    @objc private func togglePasteText() { Settings.pasteText.toggle() }

    @objc private func clearAll() {
        store.removeAll()
        refreshBadge()
    }

    @objc private func toggleAutoPaste() {
        Settings.autoPaste.toggle()
        if Settings.autoPaste && !Permissions.hasAccessibility() { Permissions.openAccessibilitySettings() }
    }

    @objc private func toggleDoubleCommand() {
        Settings.doubleCommandCapture.toggle()
        handlers.doubleCommandChanged(Settings.doubleCommandCapture)
        if Settings.doubleCommandCapture && !Permissions.hasAccessibility() { Permissions.openAccessibilitySettings() }
    }

    @objc private func toggleFrontAppAsTerminal() {
        guard let bundleID = frontAppBundleID else { return }
        var extra = Settings.extraTerminalBundleIDs
        if extra.remove(bundleID) == nil { extra.insert(bundleID) }
        Settings.extraTerminalBundleIDs = extra
        handlers.terminalsChanged()
    }

    @objc private func toggleSkill(_ sender: NSMenuItem) {
        let agents = SkillInstaller.presentAgents
        guard agents.indices.contains(sender.tag) else { return }
        let agent = agents[sender.tag]
        do {
            if SkillInstaller.state(of: agent).isInstalled {
                try SkillInstaller.uninstall(for: agent)
            } else {
                try SkillInstaller.install(for: agent)
            }
        } catch {
            NSLog("Yetda: /shots skill for \(agent.name): \(error.localizedDescription)")
            flash("⚠︎ skill")
        }
    }

    @objc private func choosePasteKey(_ sender: NSMenuItem) {
        Settings.pasteKeyOverride = Self.pasteKeyChoices[sender.tag].key
    }
}

private extension NSControl.StateValue {
    init(_ isOn: Bool) { self = isOn ? .on : .off }
}
