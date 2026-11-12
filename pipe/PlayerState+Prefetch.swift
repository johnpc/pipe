import Foundation

/// Refresh the next item's stream URL shortly before the current one ends, so
/// the end-of-item hand-off plays at once instead of waiting on a fetch. Driven
/// from the periodic progress tick. (A fetch at the hand-off itself was often
/// suspended by iOS in the background — +Hold is the safety net for that.)
extension PlayerState {
    func prefetchNextIfNeeded(at time: Double) {
        let next = NextItemPrefetchPolicy.candidate(
            queue: queue, currentIndex: currentIndex, currentTime: time, duration: duration,
            now: Date(), inFlight: transition.prefetching,
            isLocal: { [downloads] in downloads?.localURLString(for: $0) != nil })
        guard let next else { return }
        transition.prefetching = next.videoId
        log.event("prefetch", "start", fields: ["videoId": next.videoId])
        Task { [weak self] in
            let refreshed = await Self.reresolve(next)
            await MainActor.run { self?.finishPrefetch(of: next.videoId, with: refreshed) }
        }
    }

    /// Store the fresh URLs unless the item started playing meanwhile (its own
    /// load path resolved it). On failure `prefetching` keeps the id so the tick
    /// doesn't hammer the instance; the hand-off's own refresh is the retry.
    func finishPrefetch(of videoId: String, with refreshed: QueueItem?) {
        guard let refreshed else {
            log.event("prefetch", "failed", fields: ["videoId": videoId])
            return
        }
        transition.prefetching = nil
        guard currentVideoId != videoId else { return }
        updateQueueItem(refreshed)
        log.event("prefetch", "done", fields: ["videoId": videoId])
    }
}
