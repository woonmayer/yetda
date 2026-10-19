import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YetdaCore

/// Reads a capture's text with on-device OCR, masks any secrets in the PNG
/// in place, and returns the (redacted) text. Nothing leaves the Mac: OCR
/// and the optional model check both run locally.
enum ScreenshotScanner {
    struct Result: Sendable {
        /// Number of secrets masked in the file.
        var hiddenCount = 0
        /// The capture's text, top to bottom, with secrets replaced.
        var text = ""
        /// The PNG as captured, before masking; nil if nothing was masked.
        var original: Data?
        /// Secrets were found but the masked image couldn't be saved, so the
        /// file still shows them and must not be shared.
        var maskingFailed = false
    }

    /// Runs off the main actor; OCR takes a few hundred milliseconds.
    /// With `redact`, fails closed: if the image can't be read, recognized,
    /// or masked, the result says `maskingFailed` rather than letting an
    /// unchecked capture through.
    static func scan(_ url: URL, redact: Bool) async -> Result {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            NSLog("Yetda: could not read \(url.lastPathComponent) to scan it.")
            return Result(maskingFailed: redact)
        }
        guard let lines = TextRecognizer.lines(in: image) else { return Result(maskingFailed: redact) }
        guard redact else { return Result(text: lines.map(\.best.text).joined(separator: "\n")) }

        // Every line's candidates go to the on-device model in one request,
        // then the plan adds what only shows across lines (key bodies, wraps).
        let texts = lines.map {
            ScreenshotRedaction.Line(best: $0.best.text, alternatives: $0.alternatives.map(\.text))
        }
        let bests = texts.map(\.best)
        let flagged = await LocalModel.secrets(candidates: bests.map(SecretDetector.candidates(in:)), in: bests)
        let plans = ScreenshotRedaction.plan(texts, flagged: flagged)

        var rects: [CGRect] = []
        for (line, plan) in zip(lines, plans) where !plan.ranges.isEmpty {
            let reading = plan.reading == 0 ? line.best : line.alternatives[plan.reading - 1]
            guard let located = locate(plan.ranges, in: reading) else {
                NSLog("Yetda: found a secret but couldn't locate it in the image; not sharing the capture.")
                return Result(maskingFailed: true)
            }
            rects += located
        }
        let text = plans.map(\.redactedText).joined(separator: "\n")
        guard !rects.isEmpty else { return Result(text: text) }

        let original: Data?
        do {
            original = try Data(contentsOf: url)
        } catch {
            NSLog("Yetda: could not keep the unmasked original: \(error.localizedDescription)")
            original = nil
        }
        guard let masked = SecretMasker.mask(rects, in: image), writePNG(masked, to: url) else {
            NSLog("Yetda: secrets found but the masked capture couldn't be saved; not sharing it.")
            return Result(maskingFailed: true)
        }
        return Result(hiddenCount: rects.count, text: text, original: original)
    }

    /// The image rects for every range, or nil if any can't be located.
    private static func locate(_ ranges: [Range<String.Index>], in reading: LineReading) -> [CGRect]? {
        let rects = ranges.compactMap(reading.rect(for:))
        return rects.count == ranges.count ? rects : nil
    }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}
