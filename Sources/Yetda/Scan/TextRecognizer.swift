import CoreGraphics
import CoreML
import Foundation
import os
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
    /// takes a few seconds (around 20 s on macOS 27, which compiles it).
    static func warmUp(done: @escaping @Sendable () -> Void = {}) {
        DispatchQueue.global(qos: .utility).async {
            defer { done() }
            guard let context = CGContext(
                data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let image = context.makeImage() else { return }
            _ = lines(in: image)
        }
    }

    /// The image's text lines, top to bottom, then left to right; nil if
    /// recognition failed (as opposed to finding no text).
    ///
    /// One recognition at a time: on macOS 27 the first one compiles the
    /// model into the app's cache (around 20 s), and a second one started
    /// meanwhile fails with E5RT error 13. So later captures wait for it
    /// instead. A failed round is retried once, then with fallbacks.
    static func lines(in image: CGImage) -> [RecognizedLine]? {
        gate.lock()
        busy.withLock { $0 = true }
        defer {
            busy.withLock { $0 = false }
            gate.unlock()
        }
        for round in 1...2 {
            for attempt in Attempt.allCases {
                let request = makeRequest(attempt)
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                } catch {
                    log.error("text recognition failed (\(attempt.name, privacy: .public), round \(round)): \(String(describing: error), privacy: .public)")
                    continue
                }
                if attempt != .standard || round > 1 {
                    log.notice("text recognition worked with \(attempt.name, privacy: .public) in round \(round)")
                }
                return (request.results ?? [])
                    .sorted(by: readingOrder)
                    .compactMap { observation in
                        let readings = observation.topCandidates(3).map { LineReading(text: $0.string, recognized: $0) }
                        guard let best = readings.first else { return nil }
                        return RecognizedLine(best: best, alternatives: Array(readings.dropFirst()))
                    }
            }
            if round == 1 { Thread.sleep(forTimeInterval: 0.5) }
        }
        return nil
    }

    /// Whether a recognition (or the warm-up) is running, so a new capture
    /// will wait for it.
    static var isBusy: Bool { busy.withLock { $0 } }

    private static let gate = NSLock()
    private static let busy = OSAllocatedUnfairLock(initialState: false)

    /// Recognition setups, most capable first.
    private enum Attempt: Int, CaseIterable {
        /// Latest model, wherever Vision runs it (usually the Neural Engine).
        case standard
        /// Latest model, kept off the Neural Engine.
        case cpuOnly
        /// The fast recognizer. macOS 27 has a Vision bug where the accurate
        /// model fails with E5RT error 13 (its cache can be purged or left
        /// empty) and keeps failing for the rest of the process; the fast
        /// one still works. Reads less exactly, but masks rather than blocks.
        case fast

        var name: String {
            switch self {
            case .standard: "standard"
            case .cpuOnly: "CPU only"
            case .fast: "fast recognizer"
            }
        }
    }

    private static let log = Logger(subsystem: "io.github.woonmayer.yetda", category: "ocr")

    private static func makeRequest(_ attempt: Attempt) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // keep tokens exactly as shown
        switch attempt {
        case .standard:
            request.automaticallyDetectsLanguage = true // reads keys best and keeps CJK lines
        case .cpuOnly:
            request.automaticallyDetectsLanguage = true
            runOnCPU(request)
        case .fast:
            request.recognitionLevel = .fast
        }
        return request
    }

    private static func runOnCPU(_ request: VNRequest) {
        if #available(macOS 14, *) {
            guard let stages = try? request.supportedComputeStageDevices else { return }
            for (stage, devices) in stages {
                if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        } else {
            request.usesCPUOnly = true
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
