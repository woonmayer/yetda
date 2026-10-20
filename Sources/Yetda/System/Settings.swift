import Foundation
import YetdaCore

/// User preferences, stored in UserDefaults under the app's bundle ID.
/// `extraTerminalBundleIDs` and `pasteKeyByApp` are edited from the menu
/// ("Paste Into") or with `defaults write`.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static var autoPaste: Bool {
        get { bool("autoPaste", default: true) }
        set { defaults.set(newValue, forKey: "autoPaste") }
    }

    static var doubleCommandCapture: Bool {
        get { bool("doubleCommandCapture", default: true) }
        set { defaults.set(newValue, forKey: "doubleCommandCapture") }
    }

    /// Mask API keys, tokens and passwords found in each capture.
    static var redactSecrets: Bool {
        get { bool("redactSecrets", default: true) }
        set { defaults.set(newValue, forKey: "redactSecrets") }
    }

    /// After auto-pasting the image, also paste the text read from it.
    static var pasteText: Bool {
        get { bool("pasteText", default: false) }
        set { defaults.set(newValue, forKey: "pasteText") }
    }

    /// Before 0.3.2 one paste key could be forced for every app. It now
    /// becomes the key of each terminal and added app that has none of its
    /// own, so nothing pastes differently after the update.
    static func migrateGlobalPasteKey() {
        guard let raw = defaults.string(forKey: "pasteKey") else { return }
        if let key = PasteTarget.PasteKey(rawValue: raw) {
            var keys = pasteKeyByApp
            for id in PasteTarget.terminalBundleIDs.union(extraTerminalBundleIDs) where keys[id] == nil {
                keys[id] = key
            }
            pasteKeyByApp = keys
        }
        defaults.removeObject(forKey: "pasteKey")
    }

    /// The paste key the user picked per app (bundle ID → key), for added
    /// apps and built-in ones alike. Apps not in it use their default.
    static var pasteKeyByApp: [String: PasteTarget.PasteKey] {
        get {
            let raw = defaults.dictionary(forKey: "pasteKeyByApp") as? [String: String] ?? [:]
            return raw.compactMapValues(PasteTarget.PasteKey.init(rawValue:))
        }
        set { defaults.set(newValue.mapValues(\.rawValue), forKey: "pasteKeyByApp") }
    }

    static var extraTerminalBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "extraTerminalBundleIDs") ?? []) }
        set { defaults.set(newValue.sorted(), forKey: "extraTerminalBundleIDs") }
    }

    /// Whether the first-launch "Add the /shots skill?" question was asked.
    static var skillOfferShown: Bool {
        get { bool("skillOfferShown", default: false) }
        set { defaults.set(newValue, forKey: "skillOfferShown") }
    }

    /// Digest of the skill file Yetda last wrote, by path, to tell its own
    /// copies (safe to update or remove) from ones the user edited.
    static var skillDigests: [String: String] {
        get { defaults.dictionary(forKey: "skillDigests") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "skillDigests") }
    }

    private static func bool(_ key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }
}
