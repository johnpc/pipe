import Foundation

/// Which playback gets remembered in watch history. A live stream has no
/// position worth resuming and never "completes", so recording it would put a
/// broadcast on the Continue Listening shelf and in Recents with a bogus
/// progress bar. Pure, so the rule is tested without a player.
enum RecentsPolicy {
    static func records(_ item: QueueItem) -> Bool { !item.isLive }

    /// Whether a position update for `videoId` should be saved, given the queue.
    static func recordsProgress(for videoId: String, in queue: [QueueItem]) -> Bool {
        guard let item = queue.first(where: { $0.videoId == videoId }) else { return true }
        return records(item)
    }

    /// Seconds the position must move before it is written again: 10 s, or 5%
    /// of a short video. Losing that much on a crash only means resuming early.
    static func positionGranularity(duration: Int) -> Double {
        duration > 0 ? min(10, 0.05 * Double(duration)) : 10
    }

    /// Whether a new position is worth writing over `item`'s stored one: it
    /// moved enough, was reset to the start, or crosses the "watched" line
    /// (so the watched badge never lags behind).
    static func shouldRecordPosition(_ timestamp: Double, over item: RecentItem) -> Bool {
        if timestamp == item.timestamp { return false }
        if timestamp == 0 || abs(timestamp - item.timestamp) >= positionGranularity(duration: item.duration) { return true }
        guard item.duration > 0 else { return false }
        let line = 0.9 * Double(item.duration)
        return (item.timestamp < line) != (timestamp < line)
    }
}
