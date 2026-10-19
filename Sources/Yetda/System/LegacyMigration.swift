import Foundation

/// One-time carry-over from the app's previous name, ClipShot: its settings
/// (a different bundle ID, so a different defaults domain) and its capture
/// folder, `~/ClipShot/`.
enum LegacyMigration {
    private static let oldBundleID = "io.github.woonmayer.clipshot"
    private static let doneKey = "migratedFromClipShot"
    private static let settingKeys = [
        "autoPaste", "doubleCommandCapture", "pasteKey", "redactSecrets", "pasteText", "extraTerminalBundleIDs",
    ]

    /// Call before the capture folder is created.
    static func run(newFolder: URL) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)

        if let old = defaults.persistentDomain(forName: oldBundleID) {
            for key in settingKeys where defaults.object(forKey: key) == nil {
                if let value = old[key] { defaults.set(value, forKey: key) }
            }
        }

        let fm = FileManager.default
        let oldFolder = newFolder.deletingLastPathComponent().appendingPathComponent("ClipShot", isDirectory: true)
        guard fm.fileExists(atPath: oldFolder.path), !fm.fileExists(atPath: newFolder.path) else { return }
        do {
            try fm.moveItem(at: oldFolder, to: newFolder)
        } catch {
            NSLog("Yetda: could not move ~/ClipShot to \(newFolder.path): \(error.localizedDescription)")
        }
    }
}
