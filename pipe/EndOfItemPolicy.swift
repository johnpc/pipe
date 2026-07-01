import Foundation

/// Pure decision for what an end-of-item event means, so the branchy part is
/// unit-testable without a live AVPlayer.
///
/// `AVPlayerItemDidPlayToEndTime` normally means the item genuinely finished.
/// But a truncated or expired Piped stream can fire it (or a
/// FailedToPlayToEndTime) far short of the real duration — the "1-hour video
/// ends at 30 min" bug. When the reported position is well below the expected
/// duration and we have retries left, we reload to recover rather than
/// advancing the queue as if the item finished.
enum EndOfItemPolicy {
    /// Fraction of expected duration below which an end is treated as premature.
    static let prematureFraction = 0.95
    /// Absolute floor so tiny clips near their end aren't misread as premature.
    static let minGap = 5.0
    /// Cap on reload attempts before we give up and advance normally.
    static let maxRetries = 2

    enum Outcome: Equatable {
        /// The item finished as expected; advance the queue.
        case finished
        /// It ended early; reload the current item to recover.
        case recover
        /// It ended early but we're out of retries; advance so we don't loop.
        case giveUp
    }

    /// - Parameters:
    ///   - reached: playback position when the end fired.
    ///   - expected: Piped-reported duration, if known (>0).
    ///   - retries: reloads already attempted for this item.
    static func outcome(reached: Double, expected: Double?, retries: Int) -> Outcome {
        guard let expected, expected > 0 else { return .finished }
        let threshold = min(expected - minGap, expected * prematureFraction)
        guard reached < threshold else { return .finished }
        return retries < maxRetries ? .recover : .giveUp
    }
}
