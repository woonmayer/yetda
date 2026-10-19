import Foundation

/// Runs an interactive `screencapture` selection into a file.
public struct CaptureService: Sendable {
    public enum Outcome: Equatable, Sendable {
        case captured
        /// The user pressed Esc (or `screencapture` wrote nothing).
        case cancelled
        /// `screencapture` couldn't be launched.
        case failed
    }

    /// What `run` returns when the process couldn't be launched.
    public static let launchFailure: Int32 = -1

    public static let executablePath = "/usr/sbin/screencapture"

    public static func arguments(forOutputPath path: String) -> [String] {
        ["-i", path]
    }

    private let run: @Sendable ([String]) -> Int32
    private let fileExists: @Sendable (String) -> Bool

    /// - Parameters:
    ///   - run: launches `screencapture` with the given arguments and returns its exit code.
    ///   - fileExists: checks the output path afterwards.
    public init(
        run: @escaping @Sendable ([String]) -> Int32,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.run = run
        self.fileExists = fileExists
    }

    /// Blocks until the user finishes or cancels the selection. Esc exits
    /// without writing a file, so a capture needs both a zero exit code and
    /// the file.
    public func capture(toFile path: String) -> Outcome {
        let code = run(Self.arguments(forOutputPath: path))
        if code == Self.launchFailure { return .failed }
        return code == 0 && fileExists(path) ? .captured : .cancelled
    }
}
