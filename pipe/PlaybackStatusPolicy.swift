import AVFoundation

/// Pure mapping from AVPlayer's `timeControlStatus` to our `isPlaying` intent,
/// so the decision is unit-testable without a live player.
///
/// `timeControlStatus` is the source of truth for play/pause: an external pause
/// (Picture-in-Picture, the lock screen, Control Center) pauses the AVPlayer
/// directly without calling `PlayerState.pause()`, so we must adopt the player's
/// real state instead of fighting it. (The previous logic re-issued `play()` on
/// `.paused`, which silently undid every external pause — the PiP pause bug.)
enum PlaybackStatusPolicy {
    /// The new `isPlaying` value for a status change, given the current value.
    /// - `.playing` → true
    /// - `.paused` → false (honor a deliberate/external pause)
    /// - `.waitingToPlayAtSpecifiedRate` → unchanged (a transient buffering
    ///   state AVPlayer recovers from on its own; flipping the UI would flicker).
    static func isPlaying(for status: AVPlayer.TimeControlStatus, current: Bool) -> Bool {
        switch status {
        case .playing: return true
        case .paused: return false
        case .waitingToPlayAtSpecifiedRate: return current
        @unknown default: return current
        }
    }
}
