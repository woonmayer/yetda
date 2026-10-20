import Foundation
import YetdaCore

/// User preferences, stored in UserDefaults under the app's bundle ID.
/// `extraTerminalBundleIDs` and `pasteKeyByApp` are edited from the menu
/// ("Also Paste into …", "Paste Apps") or with `defaults write`.
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

    /// nil means automatic: the terminal's own paste key.
    static var pasteKeyOverride: PasteTarget.PasteKey? {
        get { defaults.string(forKey: "pasteKey").flatMap(PasteTarget.PasteKey.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "pasteKey") }
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
