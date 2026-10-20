import Foundation

/// Decides which apps Yetda auto-pastes into, and which key pastes an image
/// there: terminal emulators, where coding agents (Claude Code, Codex,
/// Gemini CLI, …) run, and the agents' own desktop apps (Claude, Codex,
/// ChatGPT). Users can add any other app, and pick ⌃V or ⌘V for it.
public enum PasteTarget {
    public enum PasteKey: String, Equatable, Sendable { case controlV, commandV }

    /// Desktop apps of coding agents. Their composer takes an image on ⌘V,
    /// like any Mac text field.
    public static let agentAppBundleIDs: Set<String> = [
        "com.anthropic.claudefordesktop", // Claude
        "com.openai.codex",               // Codex
        "com.openai.chat",                // ChatGPT
    ]

    // Terminals that keep Ctrl+V for themselves; agents there take an image paste on ⌘V.
    private static let commandVTerminalBundleIDs: Set<String> = [
        "com.googlecode.iterm2",
    ]
    private static let commandVBundleIDs = commandVTerminalBundleIDs.union(agentAppBundleIDs)

    /// The built-in set: terminals and agent desktop apps.
    public static var builtInBundleIDs: Set<String> { terminalBundleIDs.union(agentAppBundleIDs) }

    /// The key to paste with, most specific first: the key the user picked
    /// for this app, then the one forced for all apps (some agents, e.g.
    /// Cursor CLI, want ⌘V everywhere), then the app's own default — ⌃V in
    /// the known terminals (⌘V in iTerm2), ⌘V anywhere else, since any Mac
    /// text field takes an image on ⌘V.
    public static func pasteKey(
        bundleID: String?, override: PasteKey? = nil, perApp: [String: PasteKey] = [:]
    ) -> PasteKey {
        if let bundleID = bundleID, let chosen = perApp[bundleID] { return chosen }
        if let override = override { return override }
        guard let bundleID = bundleID else { return .controlV }
        if commandVBundleIDs.contains(bundleID) { return .commandV }
        return terminalBundleIDs.contains(bundleID) ? .controlV : .commandV
    }

    public static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "co.zeit.hyper",
        "com.cmuxterm.app",
        "com.stablyai.orca",
        "fun.tw93.kaku",
    ]

    public static func isAgentApp(bundleID: String?) -> Bool {
        bundleID.map(agentAppBundleIDs.contains) ?? false
    }

    /// A terminal, an agent's desktop app, or an app the user added.
    public static func isPasteTarget(bundleID: String?, extra: Set<String> = []) -> Bool {
        guard let bundleID = bundleID else { return false }
        return terminalBundleIDs.contains(bundleID) || agentAppBundleIDs.contains(bundleID) || extra.contains(bundleID)
    }
}
