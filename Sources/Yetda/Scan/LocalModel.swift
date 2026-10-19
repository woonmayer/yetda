import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Second opinion from Apple's on-device language model (macOS 26+, with
/// Apple Intelligence on) for strings that look random but match no known
/// key format. Unavailable model, error, or timeout → nothing is flagged, and
/// the pattern-based redaction still applies.
enum LocalModel {
    /// For the whole capture: one request, so a screen full of candidates
    /// can't run past the deadline line by line and slip through unjudged.
    private static let timeout: Duration = .seconds(5)
    /// How much of each candidate's line the model sees as context.
    private static let contextLength = 160

    /// Of `candidates` (per line, ranges of `lines`), those the model judges
    /// to be credentials, per line.
    static func secrets(
        candidates: [[Range<String.Index>]], in lines: [String]
    ) async -> [[Range<String.Index>]] {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { return await judged(candidates, in: lines) }
        #endif
        return lines.map { _ in [] }
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    @Generable
    struct Verdict {
        @Guide(description: "Numbers of the strings that are secret credentials; empty if none")
        var secretNumbers: [Int]
    }

    @available(macOS 26, *)
    private static func judged(
        _ candidates: [[Range<String.Index>]], in lines: [String]
    ) async -> [[Range<String.Index>]] {
        var flagged = lines.map { _ in [Range<String.Index>]() }
        let items = candidates.enumerated().flatMap { line, ranges in ranges.map { (line: line, range: $0) } }
        guard !items.isEmpty else { return flagged }
        let entries = items.map { item in
            "\(lines[item.line][item.range])   (on the line: \(lines[item.line].prefix(contextLength)))"
        }
        let numbers = await withTaskGroup(of: Set<Int>?.self) { group in
            group.addTask { try? await judge(entries) }
            group.addTask { try? await Task.sleep(for: timeout); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
        for (index, item) in items.enumerated() where numbers.contains(index + 1) {
            flagged[item.line].append(item.range)
        }
        return flagged
    }

    @available(macOS 26, *)
    private static func judge(_ entries: [String]) async throws -> Set<Int> {
        guard case .available = SystemLanguageModel.default.availability else { return [] }
        let session = LanguageModelSession(instructions: """
            You check text read from a screenshot for leaked credentials: API keys, \
            access tokens, session secrets, passwords, private keys. Hashes, IDs, \
            file names, base64 data and ordinary words are not credentials.
            """)
        let list = entries.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let response = try await session.respond(
            to: "Which of these strings from a screenshot are secret credentials?\n\(list)",
            generating: Verdict.self
        )
        return Set(response.content.secretNumbers)
    }
    #endif
}
