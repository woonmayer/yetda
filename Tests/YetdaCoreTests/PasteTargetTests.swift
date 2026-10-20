import XCTest
@testable import YetdaCore

final class PasteTargetTests: XCTestCase {
    func test_known_terminals_are_targets() {
        XCTAssertTrue(PasteTarget.isPasteTarget(bundleID: "com.apple.Terminal"))
        XCTAssertTrue(PasteTarget.isPasteTarget(bundleID: "com.googlecode.iterm2"))
        XCTAssertTrue(PasteTarget.isPasteTarget(bundleID: "com.mitchellh.ghostty"))
    }

    func test_non_terminals_and_nil_are_not_targets() {
        XCTAssertFalse(PasteTarget.isPasteTarget(bundleID: "com.google.Chrome"))
        XCTAssertFalse(PasteTarget.isPasteTarget(bundleID: nil))
    }

    func test_iterm_pastes_with_command_v_others_with_control_v() {
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.googlecode.iterm2"), .commandV)
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.apple.Terminal"), .controlV)
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.cmuxterm.app"), .controlV)
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: nil), .controlV)
    }

    func test_override_wins_over_terminal_default() {
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.apple.Terminal", override: .commandV), .commandV)
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.googlecode.iterm2", override: .controlV), .controlV)
    }

    func test_extra_bundle_ids_are_targets() {
        XCTAssertTrue(PasteTarget.isPasteTarget(bundleID: "com.example.term", extra: ["com.example.term"]))
        XCTAssertFalse(PasteTarget.isPasteTarget(bundleID: "com.example.term"))
    }

    func test_agent_desktop_apps_are_targets_and_paste_with_command_v() {
        for id in ["com.anthropic.claudefordesktop", "com.openai.codex", "com.openai.chat"] {
            XCTAssertTrue(PasteTarget.isPasteTarget(bundleID: id), id)
            XCTAssertTrue(PasteTarget.isAgentApp(bundleID: id), id)
            XCTAssertEqual(PasteTarget.pasteKey(bundleID: id), .commandV, id)
        }
        XCTAssertFalse(PasteTarget.isAgentApp(bundleID: "com.apple.Terminal"))
    }

    func test_override_also_applies_to_agent_apps() {
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.anthropic.claudefordesktop", override: .controlV), .controlV)
    }
}
