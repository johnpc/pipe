import Foundation

/// Periodic playback-time handling for PlayerState, extracted from the time
/// observer closure so it is directly unit-testable.
extension PlayerState {
    /// Handle a periodic playback-time update: publish the current time, adopt a
    /// valid item duration, and persist progress.
    func handleProgress(currentTime time: Double, itemDuration: Double?) {
        self.currentTime = time
        if let d = itemDuration, d.isFinite, d > 0 { self.duration = d }
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: time)
            updateCurrentChapter(for: vid, at: time)
        }
        logProgressHeartbeat(at: time)
    }
}
