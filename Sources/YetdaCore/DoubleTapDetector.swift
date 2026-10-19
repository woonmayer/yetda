import Foundation

/// Recognizes a double tap of a single modifier key (e.g. ⌘ ⌘): two short
/// press-release taps in quick succession with nothing else pressed between.
public struct DoubleTapDetector: Sendable {
    public enum Input: Sendable {
        case down   // the modifier went down on its own
        case up     // all modifiers released
        case other  // any other key or modifier combination
    }

    public let maxTapDuration: TimeInterval
    public let maxGap: TimeInterval

    private var downAt: TimeInterval?
    private var lastTapAt: TimeInterval?

    public init(maxTapDuration: TimeInterval = 0.3, maxGap: TimeInterval = 0.4) {
        self.maxTapDuration = maxTapDuration
        self.maxGap = maxGap
    }

    /// Feeds one input at time `t` (seconds). Returns true when it completes a
    /// double tap.
    public mutating func handle(_ input: Input, at t: TimeInterval) -> Bool {
        switch input {
        case .down:
            downAt = t
            return false
        case .other:
            downAt = nil
            lastTapAt = nil
            return false
        case .up:
            guard let down = downAt, t - down <= maxTapDuration else {
                downAt = nil
                lastTapAt = nil
                return false
            }
            downAt = nil
            if let last = lastTapAt, t - last <= maxGap {
                lastTapAt = nil
                return true
            }
            lastTapAt = t
            return false
        }
    }
}
