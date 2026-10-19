import XCTest
@testable import YetdaCore

/// Decisions across a whole capture: which parts of which lines to hide.
final class ScreenshotRedactionTests: XCTestCase {
    /// The hidden substrings of each line's chosen reading.
    private func hidden(_ lines: [String]) -> [[String]] {
        let plans = ScreenshotRedaction.plan(lines.map { ScreenshotRedaction.Line(best: $0) })
        return zip(lines, plans).map { line, plan in plan.ranges.map { String(line[$0]) } }
    }

    func test_clean_lines_pass_through() {
        let lines = ["$ npm run dev", "ready on http://localhost:3000"]
        let plans = ScreenshotRedaction.plan(lines.map { ScreenshotRedaction.Line(best: $0) })
        XCTAssertEqual(plans.map(\.ranges), [[], []])
        XCTAssertEqual(plans.map(\.redactedText), lines)
    }

    // MARK: - Private keys

    func test_private_key_body_lines_are_hidden() {
        let lines = [
            "$ cat ~/.ssh/id_rsa",
            "-----BEGIN OPENSSH PRIVATE KEY-----",
            "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn",
            "NhAAAAAwEAAQAAAYEAy1zGq0m8xC+abc/def==",
            "-----END OPENSSH PRIVATE KEY-----",
            "$ ls",
        ]
        XCTAssertEqual(hidden(lines), [
            [],
            ["-----BEGIN OPENSSH PRIVATE KEY-----"],
            ["b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn"],
            ["NhAAAAAwEAAQAAAYEAy1zGq0m8xC+abc/def=="],
            [],
            [],
        ])
    }

    func test_private_key_body_with_ocr_spaces_is_hidden_whole() {
        let lines = [
            "-----BEGIN RSA PRIVATE KEY-----",
            "MIIEvQIBADANBgkqhkiG9w0BAQEF AASCBKcwggSjAgEAAoIBAQC7",
        ]
        XCTAssertEqual(hidden(lines)[1], ["MIIEvQIBADANBgkqhkiG9w0BAQEF AASCBKcwggSjAgEAAoIBAQC7"])
    }

    func test_private_key_block_ends_at_a_line_that_is_not_base64() {
        let lines = [
            "-----BEGIN PRIVATE KEY-----",
            "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC",
            "Error: invalid key format",
            "please check the file and try again",
        ]
        let result = hidden(lines)
        XCTAssertEqual(result[1], ["MIIEvQIBADANBgkqhkiG9w0BAQEFAASC"])
        XCTAssertEqual(result[2], [])
        XCTAssertEqual(result[3], [])
    }

    func test_encrypted_key_header_fields_are_skipped_not_hidden() {
        let lines = [
            "-----BEGIN RSA PRIVATE KEY-----",
            "Proc-Type: 4,ENCRYPTED",
            "DEK-Info: AES-128-CBC,3F17F5316E2BAC89",
            "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC",
        ]
        let result = hidden(lines)
        XCTAssertEqual(result[3], ["MIIEvQIBADANBgkqhkiG9w0BAQEFAASC"])
    }

    // MARK: - Keys wrapped across lines

    func test_tail_of_a_wrapped_key_is_hidden() {
        let lines = [
            "export ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWx",
            "Yz0123456789aBcDeFgHiJ",
            "$ claude",
        ]
        XCTAssertEqual(hidden(lines), [
            ["sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWx"],
            ["Yz0123456789aBcDeFgHiJ"],
            [],
        ])
    }

    func test_key_wrapped_over_three_lines() {
        let lines = [
            "ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789",
            "Qw8Er7Ty6Ui5Op4As3Df2",
            "Gh1Jk",
        ]
        XCTAssertEqual(hidden(lines), [
            ["ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"],
            ["Qw8Er7Ty6Ui5Op4As3Df2"],
            ["Gh1Jk"],
        ])
    }

    func test_key_split_before_its_prefix_is_recognizable() {
        // Neither half matches a key format on its own.
        let lines = ["key: sk-ant-api0", "3-AbCdEfGhIjKlMnOpQrStUvWxYz0123"]
        XCTAssertEqual(hidden(lines), [["sk-ant-api0"], ["3-AbCdEfGhIjKlMnOpQrStUvWxYz0123"]])
    }

    func test_ordinary_next_line_is_not_taken_for_a_wrapped_key() {
        let after = ["$ npm run dev", "README.md updated", "at Object.<anonymous>", "Done", "Error: boom"]
        for next in after {
            XCTAssertEqual(hidden(["TOKEN=Zx9Qw8Er7Ty6Ui5Op4", next])[1], [], next)
        }
    }

    // MARK: - Readings and model verdicts

    func test_runner_up_reading_is_used_when_the_best_one_garbled_the_key() {
        let line = ScreenshotRedaction.Line(
            best: "key gh p_AbC",
            alternatives: ["key ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"]
        )
        let plan = ScreenshotRedaction.plan([line])[0]
        XCTAssertEqual(plan.reading, 1)
        XCTAssertEqual(plan.ranges.map { String(line.alternatives[0][$0]) }, ["ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"])
        XCTAssertEqual(plan.redactedText, "[REDACTED]")
    }

    func test_model_flagged_strings_are_hidden_and_redacted() {
        let text = "weird Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"
        let flagged = [SecretDetector.candidates(in: text)]
        let plan = ScreenshotRedaction.plan([ScreenshotRedaction.Line(best: text)], flagged: flagged)[0]
        XCTAssertEqual(plan.ranges.map { String(text[$0]) }, ["Qm9vT3lYcG1Ld2pSa2xNbk9wUXI4"])
        XCTAssertEqual(plan.redactedText, "weird [REDACTED]")
    }
}
