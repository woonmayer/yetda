import XCTest
@testable import YetdaCore

final class SkillInstallStateTests: XCTestCase {
    private let v1 = Data("skill v1".utf8)
    private let v2 = Data("skill v2".utf8)

    func test_missing_file_is_not_installed() {
        XCTAssertEqual(SkillInstallState(installed: nil, bundled: v2, lastWrittenDigest: nil), .notInstalled)
        XCTAssertFalse(SkillInstallState.notInstalled.isInstalled)
    }

    func test_same_as_bundled_is_up_to_date() {
        XCTAssertEqual(SkillInstallState(installed: v2, bundled: v2, lastWrittenDigest: nil), .upToDate)
    }

    func test_an_older_copy_yetda_wrote_is_outdated() {
        let state = SkillInstallState(installed: v1, bundled: v2, lastWrittenDigest: SkillInstallState.digest(v1))
        XCTAssertEqual(state, .outdated)
    }

    func test_an_edited_or_foreign_copy_is_modified() {
        let edited = Data("skill v1 + my notes".utf8)
        XCTAssertEqual(
            SkillInstallState(installed: edited, bundled: v2, lastWrittenDigest: SkillInstallState.digest(v1)),
            .modified
        )
        XCTAssertEqual(SkillInstallState(installed: v1, bundled: v2, lastWrittenDigest: nil), .modified)
        XCTAssertTrue(SkillInstallState.modified.isInstalled)
    }

    func test_digest_is_stable_hex_sha256() {
        XCTAssertEqual(
            SkillInstallState.digest(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
