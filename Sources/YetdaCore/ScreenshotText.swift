import Foundation

/// The text read from a capture, as pasted after the image.
public enum ScreenshotText {
    public static let characterLimit = 4000

    /// A short labeled block for the agent's prompt, or nil when there's no
    /// text. Long text is cut at `limit` characters.
    public static func promptBlock(_ text: String, limit: Int = characterLimit) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let body = trimmed.count > limit ? String(trimmed.prefix(limit)) + "\n…" : trimmed
        return "\nText in the screenshot:\n\(body)\n"
    }
}
