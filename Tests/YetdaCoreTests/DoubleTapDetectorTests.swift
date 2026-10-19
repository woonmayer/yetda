import XCTest
@testable import YetdaCore

final class DoubleTapDetectorTests: XCTestCase {
    private func tap(_ d: inout DoubleTapDetector, at t: TimeInterval) -> Bool {
        _ = d.handle(.down, at: t)
        return d.handle(.up, at: t + 0.05)
    }

    func test_two_quick_taps_fire() {
        var d = DoubleTapDetector()
        XCTAssertFalse(tap(&d, at: 0))
        XCTAssertTrue(tap(&d, at: 0.2))
    }

    func test_slow_second_tap_does_not_fire() {
        var d = DoubleTapDetector()
        XCTAssertFalse(tap(&d, at: 0))
        XCTAssertFalse(tap(&d, at: 1.0))
    }

    func test_held_key_is_not_a_tap() {
        var d = DoubleTapDetector()
        _ = d.handle(.down, at: 0)
        XCTAssertFalse(d.handle(.up, at: 0.6))
        XCTAssertFalse(tap(&d, at: 0.7))
    }

    func test_shortcut_in_between_cancels() {
        // ⌘C then ⌘V quickly must not count as a double tap.
        var d = DoubleTapDetector()
        _ = d.handle(.down, at: 0)
        _ = d.handle(.other, at: 0.05)
        XCTAssertFalse(d.handle(.up, at: 0.1))
        XCTAssertFalse(tap(&d, at: 0.2))
    }

    func test_triple_tap_fires_once() {
        var d = DoubleTapDetector()
        XCTAssertFalse(tap(&d, at: 0))
        XCTAssertTrue(tap(&d, at: 0.2))
        XCTAssertFalse(tap(&d, at: 0.4))
    }
}
