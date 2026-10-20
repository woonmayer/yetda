import AppKit
import UniformTypeIdentifiers
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
        /// Bundle ID of the app the next capture is pasted into.
        var nextPasteTarget: @MainActor () -> String?
        var doubleCommandChanged: @MainActor (Bool) -> Void
        var terminalsChanged: @MainActor () -> Void
    }

    private static let flashDuration: Duration = .seconds(3)

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
    private let pasteIntoItem = NSMenuItem()
    private var frontAppBundleID: String?
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
        configure(autoPasteItem, "Auto-paste", #selector(toggleAutoPaste), in: menu)
        configure(pasteIntoItem, "Paste Into", nil, in: menu).submenu = NSMenu()
        configure(doubleCommandItem, "Capture with ⌘⌘", #selector(toggleDoubleCommand), in: menu)
        configure(redactItem, "Hide Secrets in Captures", #selector(toggleRedact), in: menu)
        configure(pasteTextItem, "Also Paste Text from Capture", #selector(togglePasteText), in: menu)
        configure(skillItem, "/shots Skill", nil, in: menu).submenu = NSMenu()

        menu.addItem(.separator())
        let feedback = NSMenu()
        feedback.autoenablesItems = false
        configure(NSMenuItem(), "Report a Bug…", #selector(reportBug), in: feedback)
        configure(NSMenuItem(), "Suggest an Idea…", #selector(suggestIdea), in: feedback)
        configure(NSMenuItem(), "Feedback", nil, in: menu).submenu = feedback
        configure(NSMenuItem(), "Support Yetda…", #selector(openSponsors), in: menu)
        menu.addItem(withTitle: "Quit Yetda", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
        refreshPasteIntoMenu()
        doubleCommandItem.state = .init(Settings.doubleCommandCapture)
        redactItem.state = .init(Settings.redactSecrets)
        pasteTextItem.state = .init(Settings.pasteText)
        pasteTextItem.isEnabled = Settings.autoPaste

        refreshSkillMenu()

        screenRecordingWarning.isHidden = Permissions.hasScreenRecording
        let needsAccessibility = Settings.autoPaste || Settings.doubleCommandCapture
        accessibilityWarning.isHidden = !needsAccessibility || Permissions.hasAccessibility()
    }

    /// "Paste Into ▸": the apps a capture can be pasted into — the built-in
    /// terminals and agent apps found on this Mac, then the ones the user
    /// added — each with its paste key, which can be changed. The capture
    /// goes to whichever of them was used last, named in the item's title.
    private func refreshPasteIntoMenu() {
        let next = handlers.nextPasteTarget()
        pasteIntoItem.title = "Paste Into: \(next.map(Self.appName) ?? "—")"
        pasteIntoItem.isEnabled = Settings.autoPaste
        guard let submenu = pasteIntoItem.submenu else { return }
        submenu.removeAllItems()
        submenu.autoenablesItems = false

        let extra = Settings.extraTerminalBundleIDs
        let rows = PasteTarget.menuRows(extra: extra, perApp: Settings.pasteKeyByApp) {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
        addNote("Pastes into the one you used last.", to: submenu)
        for (title, section, removable) in [
            ("Terminals", rows.terminals, false), ("Agent Apps", rows.agentApps, false), ("Added", rows.added, true),
        ] where !section.isEmpty {
            submenu.addItem(.separator())
            addNote(title, to: submenu)
            for row in section {
                addAppRow(row, removable: removable, isNext: row.bundleID == next, to: submenu)
            }
        }

        submenu.addItem(.separator())
        let front = NSWorkspace.shared.frontmostApplication
        frontAppBundleID = front?.bundleIdentifier
        if let id = frontAppBundleID, id != Bundle.main.bundleIdentifier,
           !PasteTarget.isPasteTarget(bundleID: id, extra: extra) {
            configure(NSMenuItem(), "Add “\(front?.localizedName ?? id)”", #selector(addFrontApp), in: submenu)
        }
        configure(NSMenuItem(), "Add App…", #selector(addAppFromFolder), in: submenu)
    }

    private func addNote(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    /// "Claude   ⌘V ▸" with the key choices (and Remove, for an added app).
    /// The app the next capture goes to is ticked.
    private func addAppRow(_ row: PasteTarget.Row, removable: Bool, isNext: Bool, to menu: NSMenu) {
        let item = configure(NSMenuItem(), "\(Self.appName(row.bundleID))  \(Self.symbol(row.key))", nil, in: menu)
        item.state = .init(isNext)
        let choices = NSMenu()
        choices.autoenablesItems = false
        for choice in [PasteTarget.PasteKey.commandV, .controlV] {
            let option = configure(NSMenuItem(), "Paste with \(Self.symbol(choice))", #selector(choosePasteKeyForApp(_:)), in: choices)
            option.representedObject = [row.bundleID, choice.rawValue]
            option.state = .init(row.key == choice)
        }
        if removable {
            choices.addItem(.separator())
            configure(NSMenuItem(), "Remove", #selector(removePasteApp(_:)), in: choices).representedObject = row.bundleID
        }
        item.submenu = choices
    }

    private static func symbol(_ key: PasteTarget.PasteKey) -> String {
        key == .commandV ? "⌘V" : "⌃V"
    }

    /// The app's name as Finder shows it, or its bundle ID if it isn't installed.
    private static func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
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
    /// Opens a GitHub issue form in the browser with the version, macOS and
    /// paste target filled in; nothing is sent until the user submits it.
    @objc private func reportBug() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        #if arch(arm64)
        let chip = "Apple silicon"
        #else
        let chip = "Intel"
        #endif
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var fields = [
            "template": "bug.yml",
            "version": version,
            "macos": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion), \(chip)",
        ]
        if let target = handlers.nextPasteTarget() { fields["terminal"] = Self.appName(target) }
        openIssueForm(fields)
    }

    @objc private func suggestIdea() { openIssueForm(["template": "feature.yml"]) }

    private func openIssueForm(_ fields: [String: String]) {
        var components = URLComponents(string: "https://github.com/woonmayer/yetda/issues/new")
        components?.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        if let url = components?.url { NSWorkspace.shared.open(url) }
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

    @objc private func addFrontApp() {
        guard let bundleID = frontAppBundleID else { return }
        addPasteApps([bundleID])
    }

    /// Picks apps in a Finder dialog, starting in /Applications.
    @objc private func addAppFromFolder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose apps for Yetda to paste captures into."
        panel.prompt = "Add"
        NSApp.activate(ignoringOtherApps: true)
        let chosen = panel.runModal() == .OK ? panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier } : []
        NSApp.hide(nil) // hand focus back to the app the user was in
        addPasteApps(chosen.filter { $0 != Bundle.main.bundleIdentifier })
    }

    private func addPasteApps(_ bundleIDs: [String]) {
        let new = bundleIDs.filter { !PasteTarget.builtInBundleIDs.contains($0) }
        guard !new.isEmpty else { return }
        Settings.extraTerminalBundleIDs.formUnion(new)
        handlers.terminalsChanged()
    }

    @objc private func choosePasteKeyForApp(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let key = PasteTarget.PasteKey(rawValue: pair[1]) else { return }
        Settings.pasteKeyByApp[pair[0]] = key
    }

    @objc private func removePasteApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        Settings.extraTerminalBundleIDs.remove(bundleID)
        Settings.pasteKeyByApp[bundleID] = nil
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
}

private extension NSControl.StateValue {
    init(_ isOn: Bool) { self = isOn ? .on : .off }
}
