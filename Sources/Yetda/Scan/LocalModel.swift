import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Second opinion from Apple's on-device language model (macOS 26+, with
/// Apple Intelligence on) for strings that look random but match no known
/// key format. Unavailable model, error, or timeout → nothing is flagged, and
/// the pattern-based redaction still applies.
enum LocalModel {
    private static let timeout: Duration = .seconds(3)

    static func secrets(among ranges: [Range<String.Index>], in text: String) async -> [Range<String.Index>] {
        guard !ranges.isEmpty else { return [] }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let flagged = await withTaskGroup(of: Set<Int>?.self) { group in
                group.addTask { try? await judge(ranges.map { String(text[$0]) }, line: text) }
                group.addTask { try? await Task.sleep(for: timeout); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? []
            }
            return ranges.enumerated().filter { flagged.contains($0.offset + 1) }.map(\.element)
        }
        #endif
        return []
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    @Generable
    struct Verdict {
        @Guide(description: "Numbers of the strings that are secret credentials; empty if none")
        var secretNumbers: [Int]
    }

    @available(macOS 26, *)
    private static func judge(_ strings: [String], line: String) async throws -> Set<Int> {
        guard case .available = SystemLanguageModel.default.availability else { return [] }
        let session = LanguageModelSession(instructions: """
            You check text read from a screenshot for leaked credentials: API keys, \
            access tokens, session secrets, passwords, private keys. Hashes, IDs, \
            file names, base64 data and ordinary words are not credentials.
            """)
        let list = strings.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let response = try await session.respond(
            to: "Line from the screenshot: \(line)\n\nWhich of these strings are secret credentials?\n\(list)",
            generating: Verdict.self
        )
        return Set(response.content.secretNumbers)
    }
    #endif
}
