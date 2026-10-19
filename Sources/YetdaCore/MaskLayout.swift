import CoreGraphics

/// Geometry for masking secrets in a capture: where each mask goes and how
/// its password dots are laid out. Pure math, so it's unit-tested; drawing
/// lives in the app.
public enum MaskLayout {
    /// The part of an OCR'd word box that holds characters
    /// `secretStart..<secretEnd` (offsets into the word). OCR only boxes
    /// whole words, and `NAME=value` is one word, so the secret's share is
    /// estimated by character count, padded a little (fonts aren't monospaced).
    /// The height comes from `line`, since a word box can stop at the baseline
    /// and leave descenders showing.
    public static func secretRect(
        word: CGRect, line: CGRect, wordLength: Int, secretStart: Int, secretEnd: Int
    ) -> CGRect {
        guard wordLength > 0 else { return word }
        let charWidth = word.width / CGFloat(wordLength)
        let start = CGFloat(secretStart) * charWidth - charWidth / 4
        let end = CGFloat(secretEnd) * charWidth + charWidth / 2
        let minX = word.minX + max(0, start)
        let maxX = word.minX + min(word.width, end)
        let descender = line.height * 0.05
        return CGRect(x: minX, y: line.minY - descender, width: maxX - minX, height: line.height + descender)
    }

    /// Final mask rectangles in pixels: one height for the whole shot (the
    /// median, capped per mask) so masks on adjacent lines don't overlap
    /// when OCR boxes a line too tall, widened by `padding` on each side.
    public static func masks(for rects: [CGRect], padding: CGFloat = 2) -> [CGRect] {
        guard let height = medianHeight(of: rects) else { return [] }
        return rects.map { rect in
            let h = min(rect.height, height * 1.15)
            return CGRect(x: rect.minX - padding, y: rect.midY - h / 2, width: rect.width + 2 * padding, height: h)
                .integral
        }
    }

    public static func medianHeight(of rects: [CGRect]) -> CGFloat? {
        guard !rects.isEmpty else { return nil }
        return rects.map(\.height).sorted()[rects.count / 2]
    }

    /// A centered row of password dots inside `mask`, sized from `lineHeight`
    /// so every mask in a shot has the same dots.
    public static func dots(in mask: CGRect, lineHeight: CGFloat) -> [CGRect] {
        let diameter = max(2, lineHeight * 0.26)
        let step = diameter * 1.9
        let inset = lineHeight * 0.35
        let count = max(1, Int((mask.width - 2 * inset + step - diameter) / step))
        let rowWidth = CGFloat(count - 1) * step + diameter
        let firstX = mask.midX - rowWidth / 2
        return (0..<count).map { i in
            CGRect(x: firstX + CGFloat(i) * step, y: mask.midY - diameter / 2, width: diameter, height: diameter)
        }
    }
}
