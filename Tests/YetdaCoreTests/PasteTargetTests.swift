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

    /// Any app the user adds (an IDE, Slack, Notion, …) takes an image on ⌘V
    /// like any Mac text field; only the known terminals keep ⌃V.
    func test_added_apps_paste_with_command_v() {
        for id in ["com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "com.tinyspeck.slackmacgap", "com.example.unknown"] {
            XCTAssertEqual(PasteTarget.pasteKey(bundleID: id), .commandV, id)
        }
    }

    func test_key_chosen_for_an_app_wins() {
        let perApp: [String: PasteTarget.PasteKey] = ["com.example.term": .controlV, "com.apple.Terminal": .commandV]
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.example.term", perApp: perApp), .controlV)
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.apple.Terminal", perApp: perApp), .commandV)
        // Over the key forced for all apps, too.
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.example.term", override: .commandV, perApp: perApp), .controlV)
        // Other apps are unaffected.
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.mitchellh.ghostty", perApp: perApp), .controlV)
    }

    func test_built_in_set_is_terminals_and_agent_apps() {
        XCTAssertTrue(PasteTarget.builtInBundleIDs.contains("com.apple.Terminal"))
        XCTAssertTrue(PasteTarget.builtInBundleIDs.contains("com.anthropic.claudefordesktop"))
        XCTAssertFalse(PasteTarget.builtInBundleIDs.contains("com.tinyspeck.slackmacgap"))
    }

    func test_override_also_applies_to_agent_apps() {
        XCTAssertEqual(PasteTarget.pasteKey(bundleID: "com.anthropic.claudefordesktop", override: .controlV), .controlV)
    }

    func test_menu_rows_list_installed_built_ins_then_added_apps() {
        let installed: Set<String> = ["com.apple.Terminal", "com.mitchellh.ghostty", "com.anthropic.claudefordesktop"]
        let rows = PasteTarget.menuRows(
            extra: ["com.tinyspeck.slackmacgap", "com.apple.Terminal", "com.example.a"],
            perApp: ["com.mitchellh.ghostty": .commandV, "com.example.a": .controlV],
            isInstalled: installed.contains
        )
        XCTAssertEqual(rows.terminals, [
            .init(bundleID: "com.apple.Terminal", key: .controlV),
            .init(bundleID: "com.mitchellh.ghostty", key: .commandV),
        ])
        XCTAssertEqual(rows.agentApps, [.init(bundleID: "com.anthropic.claudefordesktop", key: .commandV)])
        // Added apps are listed even when not installed (so they can be removed);
        // a built-in one added again isn't listed twice.
        XCTAssertEqual(rows.added, [
            .init(bundleID: "com.example.a", key: .controlV),
            .init(bundleID: "com.tinyspeck.slackmacgap", key: .commandV),
        ])
    }
}
