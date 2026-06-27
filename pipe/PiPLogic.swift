import Foundation

/// Pure decision for whether Picture-in-Picture should be offered, so the logic
/// is unit-testable without AVKit.
enum PiPLogic {
    /// PiP is eligible only when the user is in video mode and there's an active
    /// player to mirror. (Audio-only playback has no video layer to float.)
    static func isEligible(videoMode: Bool, hasPlayer: Bool) -> Bool {
        videoMode && hasPlayer
    }
}
