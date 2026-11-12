import Foundation

/// Decides when to refresh the *next* queue item's stream URL ahead of time, so
/// the hand-off at end of item needs no network round trip (which, in the
/// background, iOS may suspend before it completes). Pure, for unit testing.
enum NextItemPrefetchPolicy {
    /// How close to the end of the current item (seconds) prefetching starts.
    static let leadTime: Double = 120

    /// The upcoming item to prefetch, or nil when none is due: there is no
    /// next item, the current one isn't near its end, the next item's URL will
    /// still be fresh when it plays, or that item is already being fetched.
    static func candidate(queue: [QueueItem], currentIndex: Int, currentTime: Double, duration: Double,
                          now: Date, inFlight: String?, isLocal: (String) -> Bool) -> QueueItem? {
        guard duration > 0, currentIndex >= 0, currentIndex + 1 < queue.count else { return nil }
        let remaining = duration - currentTime
        guard remaining <= leadTime else { return nil }
        let next = queue[currentIndex + 1]
        guard next.videoId != inFlight else { return nil }
        // Judge freshness as of when it will actually play, not now, so a URL
        // that expires during these last minutes is still caught.
        let playsAt = now.addingTimeInterval(max(0, remaining))
        guard StreamFreshness.needsRefresh(resolvedAt: next.resolvedAt, now: playsAt, isLocal: isLocal(next.videoId)) else {
            return nil
        }
        return next
    }
}
