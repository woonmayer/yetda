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

        // Lines are checked in parallel: each may wait on the on-device model.
        let found = await withTaskGroup(of: (Int, LineSecrets?).self) { group in
            for (index, line) in lines.enumerated() {
                group.addTask { (index, await secrets(in: line)) }
            }
            var results = [LineSecrets?](repeating: nil, count: lines.count)
            for await (index, secrets) in group { results[index] = secrets }
            return results
        }
        guard found.allSatisfy({ $0 != nil }) else {
            NSLog("Yetda: found a secret but couldn't locate it in the image; not sharing the capture.")
            return Result(maskingFailed: true)
        }
        let rects = found.flatMap { $0?.rects ?? [] }
        let text = found.map { $0?.redactedText ?? "" }.joined(separator: "\n")
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

    private struct LineSecrets: Sendable {
        var rects: [CGRect] = []
        var redactedText: String
    }

    /// Secrets in the best reading (patterns, then the on-device model for
    /// random-looking leftovers); failing that, in a runner-up reading. The
    /// same ranges mask the image and redact the text. Nil if a secret was
    /// found but couldn't be located in the image.
    private static func secrets(in line: RecognizedLine) async -> LineSecrets? {
        let best = line.best
        var ranges = SecretDetector.secretRanges(in: best.text)
        ranges += await LocalModel.secrets(among: SecretDetector.candidates(in: best.text), in: best.text)
        if !ranges.isEmpty {
            return locate(ranges, in: best).map {
                LineSecrets(rects: $0, redactedText: SecretDetector.redact(best.text, ranges: ranges))
            }
        }
        for reading in line.alternatives {
            let alternativeRanges = SecretDetector.secretRanges(in: reading.text)
            guard !alternativeRanges.isEmpty else { continue }
            // The best reading garbled the secret, so it can't be redacted
            // piece by piece: drop the whole line from the text.
            return locate(alternativeRanges, in: reading).map { LineSecrets(rects: $0, redactedText: "[REDACTED]") }
        }
        return LineSecrets(redactedText: best.text)
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
