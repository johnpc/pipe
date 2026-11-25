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
}
