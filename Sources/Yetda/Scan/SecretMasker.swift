import CoreGraphics
import YetdaCore

/// Paints password-field masks over parts of an image. Solid fills on
/// purpose: blurred or pixelated text can be recovered.
enum SecretMasker {
    private struct Palette {
        let fill: CGColor
        let dot: CGColor

        static let dark = Palette(fill: CGColor(gray: 0.30, alpha: 1), dot: CGColor(gray: 0.72, alpha: 1))
        static let light = Palette(fill: CGColor(gray: 0.86, alpha: 1), dot: CGColor(gray: 0.45, alpha: 1))
    }

    /// `image` with `rects` (Vision's normalized, bottom-left coordinates)
    /// masked, or nil if it couldn't be drawn.
    static func mask(_ rects: [CGRect], in image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixelRects = rects.map {
            CGRect(x: $0.minX * CGFloat(width), y: $0.minY * CGFloat(height),
                   width: $0.width * CGFloat(width), height: $0.height * CGFloat(height))
        }
        let masks = MaskLayout.masks(for: pixelRects)
        let lineHeight = MaskLayout.medianHeight(of: pixelRects) ?? 0
        // Sample every background before painting, then all fills, then all
        // dots, so overlapping masks read as one.
        let palettes = masks.map { luminance(around: $0, in: context) < 0.5 ? Palette.dark : Palette.light }
        for (mask, palette) in zip(masks, palettes) {
            let radius = mask.height * 0.35
            context.setFillColor(palette.fill)
            context.addPath(CGPath(roundedRect: mask, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
        for (mask, palette) in zip(masks, palettes) {
            context.setFillColor(palette.dot)
            MaskLayout.dots(in: mask, lineHeight: lineHeight).forEach(context.fillEllipse(in:))
        }
        return context.makeImage()
    }

    /// Average brightness (0–1) of the pixels just left of and above `rect`.
    private static func luminance(around rect: CGRect, in context: CGContext) -> CGFloat {
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        let width = context.width, height = context.height, bytesPerRow = context.bytesPerRow
        let samples = (0..<8).flatMap { i -> [(Int, Int)] in
            let t = CGFloat(i) / 7
            return [
                (Int(rect.minX) - 4, Int(rect.minY + rect.height * t)),
                (Int(rect.minX + rect.width * t), Int(rect.maxY) + 4),
            ]
        }
        var total: CGFloat = 0, count: CGFloat = 0
        for (x, y) in samples where (0..<width).contains(x) && (0..<height).contains(y) {
            let offset = (height - 1 - y) * bytesPerRow + x * 4 // memory rows run top-down
            let r = CGFloat(data[offset]), g = CGFloat(data[offset + 1]), b = CGFloat(data[offset + 2])
            total += (0.299 * r + 0.587 * g + 0.114 * b) / 255
            count += 1
        }
        return count > 0 ? total / count : 0
    }
}
