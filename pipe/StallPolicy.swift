import AVFoundation

/// Pure decision for AVPlayer stall recovery, so the logic is unit-testable
/// without a live player.
enum StallPolicy {
    /// Whether to nudge the player back into playing.
    ///
    /// When we intend to be playing (`intendingToPlay`) but the player reports
    /// `.paused`, that's an *involuntary* stop — a buffer-underrun stall — since
    /// a deliberate user pause sets `intendingToPlay` to false first. In that
    /// case we re-issue `play()`. `.waitingToPlayAtSpecifiedRate` is AVPlayer
    /// already recovering on its own, so we leave it alone.
    static func shouldNudge(intendingToPlay: Bool, status: AVPlayer.TimeControlStatus) -> Bool {
        intendingToPlay && status == .paused
    }
}
