import Foundation

/// Finds credentials in text read off a screenshot, so they can be blacked out
/// before the image leaves the Mac. Patterns cover well-known token formats
/// plus `key = value` assignments; `candidates` returns other long,
/// random-looking strings for a second opinion (the on-device model).
public enum SecretDetector {
    private static let patterns: [NSRegularExpression] = [
        #"sk-(?:ant-|proj-)?[A-Za-z0-9_\-]{20,}"#,                 // OpenAI / Anthropic
        #"gh[pousr]_[A-Za-z0-9]{30,}"#,                             // GitHub tokens
        #"github_pat_[A-Za-z0-9_]{30,}"#,
        #"(?:AKIA|ASIA)[0-9A-Z]{16}"#,                              // AWS access key ID
        #"xox[abprs]-[A-Za-z0-9\-]{10,}"#,                          // Slack
        #"AIza[0-9A-Za-z_\-]{35}"#,                                 // Google API key
        #"(?:sk|rk)_(?:live|test)_[0-9A-Za-z]{16,}"#,               // Stripe secret keys
        #"glpat-[0-9A-Za-z_\-]{20,}"#,                              // GitLab
        #"hf_[A-Za-z0-9]{30,}"#,                                    // Hugging Face
        #"npm_[A-Za-z0-9]{36}"#,                                    // npm
        #"eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"#, // JWT
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
        #"(?i)\bbearer\s+([A-Za-z0-9._~+/=\-]{16,})"#,                // Authorization header
        #"(?i)(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|amqps?|https?|ftp)://[^\s:/@]+:([^\s/@]+)@"#, // URL password
    ].map { try! NSRegularExpression(pattern: $0) }

    // `password: hunter2`, `API_KEY="…"`: only the value is a secret. Names
    // that merely contain "key" (`SESSION_KEY`, but also `primary key: id`)
    // count only when the value looks random.
    private static let assignment = try! NSRegularExpression(
        pattern: #"(?i)\b([A-Z0-9_\-]*(?:key|secret|token|passw(?:or)?d|pwd|auth|credential)[A-Z0-9_\-]*)["']?\s*[:=]\s*["']?([^\s"',;]{6,})"#
    )
    private static let strongName = try! NSRegularExpression(
        pattern: #"(?i)api[_-]?key|private[_-]?key|access[_-]?key|secret|token|passw(?:or)?d|pwd|credential"#
    )

    // `INTERNAL_SIGNING=Qm9vT3lY…`: an env-style assignment of a random value
    // (OCR sometimes reads a space around the `=`). `=` only: `TRACE_ID: …`
    // style log fields are usually IDs, not secrets.
    private static let envAssignment = try! NSRegularExpression(
        pattern: #"\b[A-Z][A-Z0-9_]{2,} ?= ?["']?([^\s"',;]{12,})"#
    )

    private static let cardNumber = try! NSRegularExpression(pattern: #"\b\d(?:[ -]?\d){12,18}\b"#)

    private static let longToken = try! NSRegularExpression(pattern: #"[A-Za-z0-9_\-+/=.]{24,}"#)

    /// Ranges of `text` that are secrets and must be hidden.
    public static func secretRanges(in original: String) -> [Range<String.Index>] {
        // Match on a look-alike-free copy (OCR sometimes reads Latin letters in
        // a key as Cyrillic), then map the ranges back by character offset.
        let text = normalized(original)
        return rawSecretRanges(in: text).map { range in
            let lower = original.index(original.startIndex, offsetBy: text.distance(from: text.startIndex, to: range.lowerBound))
            let upper = original.index(lower, offsetBy: text.distance(from: range.lowerBound, to: range.upperBound))
            return lower..<upper
        }
    }

    private static func rawSecretRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let whole = NSRange(text.startIndex..., in: text)
        for regex in patterns {
            for match in regex.matches(in: text, range: whole) {
                // Patterns with a capture group hide just the group (e.g. the URL password).
                let r = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound
                    ? match.range(at: 1) : match.range
                if let range = Range(r, in: text) { ranges.append(range) }
            }
        }
        for match in assignment.matches(in: text, range: whole) {
            guard let nameRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else { continue }
            let name = String(text[nameRange])
            let isStrong = strongName.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
            let value = text[valueRange]
            if isStrong ? !isPlaceholder(value) : looksRandom(value) { ranges.append(valueRange) }
        }
        for match in envAssignment.matches(in: text, range: whole) {
            // URLs and paths are left to the URL-password pattern.
            if let range = Range(match.range(at: 1), in: text), !text[range].contains("/"),
               looksRandom(text[range]) { ranges.append(range) }
        }
        for match in cardNumber.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text) else { continue }
            let digits = String(text[range].filter(\.isNumber))
            if hasCardPrefix(digits) && passesLuhn(digits) { ranges.append(range) }
        }
        return merge(ranges)
    }

    /// Long, random-looking strings the patterns didn't catch (unknown key
    /// formats). Not secrets by themselves — hashes, IDs and base64 look the
    /// same — so a caller should ask the on-device model before hiding them.
    public static func candidates(in text: String) -> [Range<String.Index>] {
        let known = secretRanges(in: text)
        return longToken.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text),
                  !known.contains(where: { $0.overlaps(range) }) else { return nil }
            let token = text[range]
            let isPath = token.contains("/") && !token.contains("+")
            return !isPath && looksRandom(token) ? range : nil
        }
    }

    /// Words that fill a password/token field without being one. A known list
    /// rather than "any lowercase word": real passwords are often plain
    /// words (`PGPASSWORD=postgres`).
    private static let placeholderWords: Set<String> = [
        "required", "optional", "undefined", "null", "nil", "none", "empty", "unset", "default",
        "string", "number", "boolean", "text", "value", "example", "sample", "placeholder",
        "redacted", "hidden", "masked", "invalid", "missing", "expired", "incorrect", "provided",
        "true", "false",
    ]

    /// `token=undefined`, `password: required`, `secret = ********`,
    /// `password: (none)`, `api_key=<your-key>`, `TOKEN=$GITHUB_TOKEN`,
    /// `password: {{db_password}}`: a type, a stand-in or a reference, not a value.
    private static func isPlaceholder(_ value: Substring) -> Bool {
        if value.allSatisfy({ "*•●x.".contains($0) }) { return true }
        if value.hasPrefix("$") || value.hasPrefix("{{") || value.hasPrefix("%")
            || (value.hasPrefix("<") && value.hasSuffix(">")) { return true }
        let word = value.trimmingCharacters(in: CharacterSet(charactersIn: "()[]{}<>")).lowercased()
        return placeholderWords.contains(word)
    }

    /// Issuer prefixes (Visa, Mastercard, Amex, Discover, JCB, UnionPay), so
    /// order numbers that happen to pass the checksum aren't hidden.
    static func hasCardPrefix(_ digits: String) -> Bool {
        let two = Int(digits.prefix(2)) ?? 0, four = Int(digits.prefix(4)) ?? 0
        return digits.hasPrefix("4") || (51...55).contains(two) || (2221...2720).contains(four)
            || ((two == 34 || two == 37) && digits.count == 15)
            || digits.hasPrefix("6011") || digits.hasPrefix("65") || two == 35 || two == 62
    }

    /// Mixed-case letters and digits, and not a hex hash or UUID.
    private static func looksRandom(_ token: Substring) -> Bool {
        guard token.count >= 12, !token.allSatisfy({ $0.isHexDigit || $0 == "-" }) else { return false }
        return token.contains(where: \.isNumber) && token.contains(where: \.isUppercase)
            && token.contains(where: \.isLowercase)
    }

    private static let lookAlikes: [Character: Character] = [
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x", "і": "i", "ј": "j", "ѕ": "s",
        "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X",
        "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M", "Ν": "N", "Ο": "O",
        "Ρ": "P", "Τ": "T", "Υ": "Y", "Χ": "X", "ο": "o",
        "—": "-", "–": "-", "‐": "-", "‑": "-", "×": "x",
    ]

    /// `text` with OCR look-alike characters mapped to ASCII, one character
    /// for one, so offsets line up with the original.
    static func normalized(_ text: String) -> String {
        String(text.map { lookAlikes[$0] ?? $0 })
    }

    /// `text` with every secret replaced by `[REDACTED]`.
    public static func redact(_ text: String) -> String {
        redact(text, ranges: secretRanges(in: text))
    }

    /// `text` with `ranges` (of `text`, possibly overlapping) replaced by `[REDACTED]`.
    public static func redact(_ text: String, ranges: [Range<String.Index>]) -> String {
        var result = text
        for range in merge(ranges).reversed() {
            result.replaceSubrange(range, with: "[REDACTED]")
        }
        return result
    }

    static func passesLuhn(_ digits: String) -> Bool {
        guard (13...19).contains(digits.count) else { return false }
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard var d = ch.wholeNumberValue else { return false }
            if i % 2 == 1 { d *= 2; if d > 9 { d -= 9 } }
            sum += d
        }
        return sum % 10 == 0
    }

    /// Sorted, with overlapping or touching ranges joined.
    static func merge(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        ranges.sorted { $0.lowerBound < $1.lowerBound }.reduce(into: []) { merged, range in
            if let last = merged.last, last.upperBound >= range.lowerBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
    }
}
