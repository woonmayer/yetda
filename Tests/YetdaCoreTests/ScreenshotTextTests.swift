import XCTest
@testable import YetdaCore

final class ScreenshotTextTests: XCTestCase {
    func test_text_is_labeled_and_trimmed() {
        XCTAssertEqual(
            ScreenshotText.promptBlock("  TypeError: x is undefined \n"),
            "\nText in the screenshot:\nTypeError: x is undefined\n"
        )
    }

    func test_blank_text_gives_nothing() {
        XCTAssertNil(ScreenshotText.promptBlock(""))
        XCTAssertNil(ScreenshotText.promptBlock(" \n\t"))
    }

    func test_long_text_is_cut_at_the_limit() {
        XCTAssertEqual(ScreenshotText.promptBlock("abcdef", limit: 3), "\nText in the screenshot:\nabc\n…\n")
    }
}
