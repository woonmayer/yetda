import CoreGraphics
import Foundation
import Vision
import YetdaCore

/// One reading of an OCR'd line: its text and Vision's handle for locating
/// substrings of it in the image.
struct LineReading: @unchecked Sendable { // VNRecognizedText is immutable once produced
    let text: String
    let recognized: VNRecognizedText

    /// Where `range` of the text sits, in Vision's normalized, bottom-left
    /// coordinates. See `MaskLayout.secretRect` for why it's an estimate.
    func rect(for range: Range<String.Index>) -> CGRect? {
        var lower = range.lowerBound
        while lower > text.startIndex, !text[text.index(before: lower)].isWhitespace {
            lower = text.index(before: lower)
        }
        var upper = range.upperBound
        while upper < text.endIndex, !text[upper].isWhitespace {
            upper = text.index(after: upper)
        }
        guard let word = try? recognized.boundingBox(for: lower..<upper)?.boundingBox else { return nil }
        let line = (try? recognized.boundingBox(for: text.startIndex..<text.endIndex)?.boundingBox) ?? word
        return MaskLayout.secretRect(
            word: word, line: line,
            wordLength: text.distance(from: lower, to: upper),
            secretStart: text.distance(from: lower, to: range.lowerBound),
            secretEnd: text.distance(from: lower, to: range.upperBound)
        )
    }
}

/// A recognized line: the best reading plus runner-ups, since a secret
/// misread in the best one is often intact in another.
struct RecognizedLine: Sendable {
    let best: LineReading
    let alternatives: [LineReading]
}

/// On-device text recognition (Vision).
enum TextRecognizer {
    /// Loads the OCR model in the background; the first recognition otherwise
    /// takes a few seconds.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async {
            guard let context = CGContext(
                data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let image = context.makeImage() else { return }
            _ = lines(in: image)
        }
    }

    /// The image's text lines, top to bottom, then left to right; nil if
    /// recognition failed (as opposed to finding no text).
    static func lines(in image: CGImage) -> [RecognizedLine]? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // keep tokens exactly as shown
        request.automaticallyDetectsLanguage = true // reads keys best and keeps CJK lines
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            NSLog("Yetda: text recognition failed: \(error.localizedDescription)")
            return nil
        }
        return (request.results ?? [])
            .sorted(by: readingOrder)
            .compactMap { observation in
                let readings = observation.topCandidates(3).map { LineReading(text: $0.string, recognized: $0) }
                guard let best = readings.first else { return nil }
                return RecognizedLine(best: best, alternatives: Array(readings.dropFirst()))
            }
    }

    // Vision's origin is bottom-left, so higher rows come first. Rows are
    // 1%-of-height bands: a fixed bucket keeps the order transitive, which a
    // "within 1% of each other" test is not.
    private static func readingOrder(_ a: VNRecognizedTextObservation, _ b: VNRecognizedTextObservation) -> Bool {
        let rowA = row(a), rowB = row(b)
        return rowA != rowB ? rowA > rowB : a.boundingBox.minX < b.boundingBox.minX
    }

    private static func row(_ observation: VNRecognizedTextObservation) -> Int {
        Int((observation.boundingBox.midY * 100).rounded())
    }
}
