import CoreGraphics
import XCTest
@testable import YetdaCore

final class MaskLayoutTests: XCTestCase {
    func test_secret_rect_covers_the_value_part_of_a_word() {
        // "KEY=abcdef": 10 chars, 10pt each; the secret is chars 4..<10.
        let word = CGRect(x: 0, y: 10, width: 100, height: 20)
        let line = CGRect(x: 0, y: 8, width: 300, height: 24)
        let rect = MaskLayout.secretRect(word: word, line: line, wordLength: 10, secretStart: 4, secretEnd: 10)
        XCTAssertEqual(rect.minX, 37.5, accuracy: 0.001) // a quarter char of slack before
        XCTAssertEqual(rect.maxX, 100, accuracy: 0.001)  // clamped to the word
        XCTAssertEqual(rect.minY, 8 - 24 * 0.05, accuracy: 0.001)
        XCTAssertEqual(rect.height, 24 * 1.05, accuracy: 0.001)
    }

    func test_secret_rect_with_empty_word_falls_back_to_the_word() {
        let word = CGRect(x: 5, y: 5, width: 10, height: 10)
        XCTAssertEqual(MaskLayout.secretRect(word: word, line: word, wordLength: 0, secretStart: 0, secretEnd: 0), word)
    }

    func test_masks_share_one_height_and_cap_tall_boxes() {
        let rects = [
            CGRect(x: 0, y: 0, width: 50, height: 20),
            CGRect(x: 0, y: 30, width: 50, height: 20),
            CGRect(x: 0, y: 60, width: 50, height: 40), // OCR boxed this line too tall
        ]
        let masks = MaskLayout.masks(for: rects, padding: 2)
        // Capped at 1.15 × the median (23), then rounded outward to whole pixels.
        XCTAssertEqual(masks.map(\.height), [20, 20, 24])
        XCTAssertEqual(masks[2].midY, 80, accuracy: 0.5) // stays centered on its line
        XCTAssertEqual(masks[0].minX, -2)
        XCTAssertEqual(masks[0].width, 54)
    }

    func test_masks_of_nothing_is_nothing() {
        XCTAssertEqual(MaskLayout.masks(for: []), [])
        XCTAssertNil(MaskLayout.medianHeight(of: []))
    }

    func test_dots_are_centered_same_size_and_inside_the_mask() {
        let mask = CGRect(x: 10, y: 10, width: 200, height: 20)
        let dots = MaskLayout.dots(in: mask, lineHeight: 20)
        XCTAssertGreaterThan(dots.count, 5)
        XCTAssertEqual(Set(dots.map(\.width)).count, 1)
        XCTAssertTrue(dots.allSatisfy { mask.contains($0) })
        let rowMid = (dots.first!.minX + dots.last!.maxX) / 2
        XCTAssertEqual(rowMid, mask.midX, accuracy: 0.001)
    }

    func test_a_tiny_mask_still_gets_one_dot() {
        XCTAssertEqual(MaskLayout.dots(in: CGRect(x: 0, y: 0, width: 4, height: 20), lineHeight: 20).count, 1)
    }
}
