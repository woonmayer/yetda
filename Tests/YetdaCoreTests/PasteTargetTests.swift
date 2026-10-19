import XCTest
@testable import YetdaCore

final class PasteTargetTests: XCTestCase {
    func test_known_terminals_are_targets() {
        XCTAssertTrue(PasteTarget.isTerminal(bundleID: "com.apple.Terminal"))
        XCTAssertTrue(PasteTarget.isTerminal(bundleID: "com.googlecode.iterm2"))
        XCTAssertTrue(PasteTarget.isTerminal(bundleID: "com.mitchellh.ghostty"))
    }

    func test_non_terminals_and_nil_are_not_targets() {
        XCTAssertFalse(PasteTarget.isTerminal(bundleID: "com.google.Chrome"))
        XCTAssertFalse(PasteTarget.isTerminal(bundleID: nil))
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
        XCTAssertTrue(PasteTarget.isTerminal(bundleID: "com.example.term", extra: ["com.example.term"]))
        XCTAssertFalse(PasteTarget.isTerminal(bundleID: "com.example.term"))
    }
}
