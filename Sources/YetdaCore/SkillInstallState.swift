import CryptoKit
import Foundation

/// Where an installed copy of the bundled `/shots` skill stands, so Yetda
/// can keep its own copy up to date without ever overwriting a user's edits.
public enum SkillInstallState: Equatable, Sendable {
    case notInstalled
    /// Identical to the bundled skill.
    case upToDate
    /// Yetda wrote it, an older version: safe to replace.
    case outdated
    /// Changed since Yetda wrote it, or not written by Yetda: leave it alone.
    case modified

    /// - Parameters:
    ///   - installed: the file's contents, or nil if it doesn't exist.
    ///   - bundled: the skill shipped with this version of the app.
    ///   - lastWrittenDigest: `digest` of what Yetda last wrote there, if anything.
    public init(installed: Data?, bundled: Data, lastWrittenDigest: String?) {
        guard let installed else { self = .notInstalled; return }
        if installed == bundled {
            self = .upToDate
        } else if Self.digest(installed) == lastWrittenDigest {
            self = .outdated
        } else {
            self = .modified
        }
    }

    public var isInstalled: Bool { self != .notInstalled }

    /// SHA-256, hex-encoded.
    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
