import Foundation

/// Decides, for a whole capture, which parts of which OCR'd lines are secret.
/// Line by line, `SecretDetector` finds keys that fit on one line; this adds
/// what only shows across lines: the body of a private key under its
/// `BEGIN … PRIVATE KEY` header, and a key the terminal wrapped onto the
/// next line. Pure text in, ranges out; locating them in the image is the
/// app's job, and if any range can't be located the capture isn't shared.
public enum ScreenshotRedaction {
    /// One OCR'd line: the best reading and the runner-ups.
    public struct Line: Sendable {
        public var best: String
        public var alternatives: [String]

        public init(best: String, alternatives: [String] = []) {
            self.best = best
            self.alternatives = alternatives
        }
    }

    /// What to hide in one line.
    public struct LinePlan: Sendable, Equatable {
        /// Which reading `ranges` index into: 0 is `best`, k is `alternatives[k - 1]`.
        public var reading: Int
        /// Sorted and merged.
        public var ranges: [Range<String.Index>]
        /// The line as pasted as text, with secrets replaced.
        public var redactedText: String
    }

    /// - Parameters:
    ///   - flagged: per line, extra ranges of `best` to hide (the on-device
    ///     model's verdicts); may be empty or shorter than `lines`.
    public static func plan(_ lines: [Line], flagged: [[Range<String.Index>]] = []) -> [LinePlan] {
        let texts = lines.map(\.best)
        var found: [[Range<String.Index>]] = texts.indices.map { i in
            SecretDetector.secretRanges(in: texts[i]) + (flagged.indices.contains(i) ? flagged[i] : [])
        }
        addPrivateKeyBodies(texts, to: &found)
        addWrappedContinuations(texts, to: &found)

        return lines.indices.map { i in
            let line = lines[i]
            if !found[i].isEmpty {
                let ranges = SecretDetector.merge(found[i])
                return LinePlan(reading: 0, ranges: ranges, redactedText: SecretDetector.redact(line.best, ranges: ranges))
            }
            // The best reading may have garbled a key that a runner-up read
            // intact. Its text can't be redacted piece by piece, so the whole
            // line goes.
            for (k, reading) in line.alternatives.enumerated() {
                let ranges = SecretDetector.secretRanges(in: reading)
                if !ranges.isEmpty { return LinePlan(reading: k + 1, ranges: ranges, redactedText: "[REDACTED]") }
            }
            return LinePlan(reading: 0, ranges: [], redactedText: line.best)
        }
    }

    // MARK: - Private key bodies

    private static let keyBegin = try! NSRegularExpression(pattern: #"BEGIN [A-Z ]*PRIVATE KEY"#)
    private static let keyEnd = try! NSRegularExpression(pattern: #"END [A-Z ]*PRIVATE KEY"#)
    /// `Proc-Type: 4,ENCRYPTED`, `DEK-Info: …` inside an encrypted key.
    private static let headerField = try! NSRegularExpression(pattern: #"^[A-Za-z][A-Za-z-]*: "#)
    private static let base64: Set<Character> = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    )

    /// Every base64 line after a `BEGIN … PRIVATE KEY` header, up to its
    /// `END` line or the first line that isn't part of a key.
    static func addPrivateKeyBodies(_ texts: [String], to found: inout [[Range<String.Index>]]) {
        var inKey = false
        for (i, raw) in texts.enumerated() {
            let text = SecretDetector.normalized(raw)
            if matches(keyBegin, text) { inKey = true; continue }
            guard inKey else { continue }
            if matches(keyEnd, text) {
                inKey = false
            } else if isBase64Line(text), let content = contentRange(of: raw) {
                found[i].append(content)
            } else if !matches(headerField, text.trimmingCharacters(in: .whitespaces)) {
                inKey = false
            }
        }
    }

    /// Base64 with OCR's stray spaces allowed. Needs all three character
    /// classes, which a key line has and an English sentence doesn't.
    static func isBase64Line(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace }
        return compact.count >= 16 && compact.allSatisfy(base64.contains)
            && compact.contains(where: \.isUppercase) && compact.contains(where: \.isLowercase)
            && compact.contains(where: \.isNumber)
    }

    // MARK: - Wrapped keys

    private static let tokenCharacters: Set<Character> = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-+/=."
    )

    /// A terminal wraps a long key onto the next line, and OCR reads the two
    /// parts as separate lines. Two cases:
    /// - a secret runs to the end of a line: the next line's first token, if
    ///   it looks like more of a key, is hidden too (repeating down the lines);
    /// - neither part is recognizable alone: the last token of a line joined
    ///   with the first token of the next is checked as one.
    static func addWrappedContinuations(_ texts: [String], to found: inout [[Range<String.Index>]]) {
        guard texts.count > 1 else { return }
        for i in 0..<(texts.count - 1) {
            let line = texts[i], next = texts[i + 1]
            guard let tail = lastToken(of: line), let head = firstToken(of: next) else { continue }

            if found[i].contains(where: { $0.upperBound == tail.upperBound }) {
                if looksLikeKeyContinuation(next[head]) { found[i + 1].append(head) }
                continue
            }

            let tailText = String(line[tail]), headText = String(next[head])
            let joined = tailText + headText
            let split = tailText.count
            for range in SecretDetector.secretRanges(in: joined) {
                let lower = joined.distance(from: joined.startIndex, to: range.lowerBound)
                let upper = joined.distance(from: joined.startIndex, to: range.upperBound)
                guard lower < split, upper > split else { continue } // must straddle the wrap
                found[i].append(line.index(tail.lowerBound, offsetBy: lower)..<tail.upperBound)
                found[i + 1].append(head.lowerBound..<next.index(head.lowerBound, offsetBy: upper - split))
            }
        }
    }

    /// The rest of a key, not an ordinary word: key characters only, and a
    /// digit, or mixed case without the dot of a file name. Short tails
    /// without digits (under 6 characters) are let through rather than
    /// hiding words like "Done".
    static func looksLikeKeyContinuation(_ token: Substring) -> Bool {
        guard token.count >= 3, token.allSatisfy(tokenCharacters.contains) else { return false }
        if token.contains(where: \.isNumber) { return true }
        return token.count >= 6 && token.contains(where: \.isUppercase) && token.contains(where: \.isLowercase)
            && !token.contains(".")
    }

    // MARK: - Helpers

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// From the first to the last non-whitespace character.
    static func contentRange(of text: String) -> Range<String.Index>? {
        guard let first = text.firstIndex(where: { !$0.isWhitespace }),
              let last = text.lastIndex(where: { !$0.isWhitespace }) else { return nil }
        return first..<text.index(after: last)
    }

    /// The last run of non-whitespace characters.
    static func lastToken(of text: String) -> Range<String.Index>? {
        guard let content = contentRange(of: text) else { return nil }
        let start = text[content].lastIndex(where: \.isWhitespace).map(text.index(after:)) ?? content.lowerBound
        return start..<content.upperBound
    }

    /// The first run of non-whitespace characters.
    static func firstToken(of text: String) -> Range<String.Index>? {
        guard let content = contentRange(of: text) else { return nil }
        let end = text[content].firstIndex(where: \.isWhitespace) ?? content.upperBound
        return content.lowerBound..<end
    }
}
