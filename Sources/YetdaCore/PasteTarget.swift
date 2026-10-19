import Foundation

/// Decides which apps Yetda auto-pastes into: terminal emulators, where
/// coding agents (Claude Code, Codex, Gemini CLI, …) run, and which key
/// pastes an image there. Users can add more terminals via the
/// `extraTerminalBundleIDs` default.
public enum PasteTarget {
    public enum PasteKey: String, Equatable, Sendable { case controlV, commandV }

    // Terminals that keep Ctrl+V for themselves; agents there take an image paste on ⌘V.
    private static let commandVBundleIDs: Set<String> = [
        "com.googlecode.iterm2",
    ]

    /// The key to paste with: `override` if the user picked one (some agents,
    /// e.g. Cursor CLI, want ⌘V everywhere), otherwise the terminal's default.
    public static func pasteKey(bundleID: String?, override: PasteKey? = nil) -> PasteKey {
        if let override = override { return override }
        guard let bundleID = bundleID, commandVBundleIDs.contains(bundleID) else { return .controlV }
        return .commandV
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

    public static func isTerminal(bundleID: String?, extra: Set<String> = []) -> Bool {
        guard let bundleID = bundleID else { return false }
        return terminalBundleIDs.contains(bundleID) || extra.contains(bundleID)
    }
}
