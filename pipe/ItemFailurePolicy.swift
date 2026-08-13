import Foundation

/// Pure decision for what a *load-time* item failure means, so the branchy part
/// is unit-testable without a live AVPlayer.
///
/// `AVPlayerItem.status == .failed` means the item never started — distinct from
/// the premature-end case `EndOfItemPolicy` covers, where playback began and then
/// stopped short. The usual cause is a stream URL that is dead on arrival: the
/// server mints it and it answers 403 to the unbounded range request AVPlayer
/// opens with, so the item fails within a second and playback sits at 0s.
///
/// Retrying the *same* URL cannot help — it's the URL that's bad, not the
/// network — so recovery has to re-resolve from the videoId to mint a new one.
enum ItemFailurePolicy {
    /// Cap on re-resolve attempts before we surface the error. Two fresh URLs is
    /// enough to clear an intermittent bad mint; beyond that the video itself is
    /// unavailable and retrying just spins.
    static let maxRetries = 2

    enum Outcome: Equatable {
        /// Re-resolve the stream URL from the videoId and try again.
        case retry
        /// Out of retries — stop and show the user an error.
        case giveUp
    }

    /// - Parameters:
    ///   - retries: re-resolve attempts already made for this item.
    ///   - isLocal: a downloaded file; its failure is corruption, not a dead URL,
    ///     so re-resolving a remote URL would be the wrong move.
    static func outcome(retries: Int, isLocal: Bool) -> Outcome {
        if isLocal { return .giveUp }
        return retries < maxRetries ? .retry : .giveUp
    }

    /// User-facing copy when recovery is exhausted. Names the item so a failure in
    /// a background queue isn't a mystery.
    static func failureMessage(title: String) -> String {
        "Couldn't play \(title) — the stream expired"
    }
}
