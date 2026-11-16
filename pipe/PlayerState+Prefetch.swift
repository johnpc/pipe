import Foundation

/// Refresh the next item's stream URL shortly before the current one ends, so
/// the end-of-item hand-off plays at once instead of waiting on a fetch. Driven
/// from the periodic progress tick. (A fetch at the hand-off itself was often
/// suspended by iOS in the background — +Hold is the safety net for that.)
/// Progress is recorded on the item itself (`QueueItem.resolution`).
extension PlayerState {
    func prefetchNextIfNeeded(at time: Double) {
        let next = NextItemPrefetchPolicy.candidate(
            queue: queue, currentIndex: currentIndex, currentTime: time, duration: duration,
            now: Date(), isLocal: { [downloads] in downloads?.localURLString(for: $0) != nil })
        guard let next else { return }
        setResolveAttempt(.inFlight, for: next.videoId)
        log.event("prefetch", "start", fields: ["videoId": next.videoId])
        let resolver = self.resolver
        Task { [weak self] in
            let refreshed = await resolver.fresh(next)
            await MainActor.run { self?.finishPrefetch(of: next.videoId, with: refreshed) }
        }
    }

    /// Store the fresh URLs unless the item started playing meanwhile (its own
    /// load path resolved it). A failure parks the item as `.failed` so the tick
    /// doesn't hammer the instance; the hand-off's own refresh is the retry.
    func finishPrefetch(of videoId: String, with refreshed: QueueItem?) {
        guard let refreshed else {
            log.event("prefetch", "failed", fields: ["videoId": videoId])
            setResolveAttempt(.failed, for: videoId)
            return
        }
        guard currentVideoId != videoId else {
            setResolveAttempt(.none, for: videoId)
            return
        }
        updateQueueItem(refreshed)  // a fresh copy carries `.none`
        log.event("prefetch", "done", fields: ["videoId": videoId])
    }

    /// Record background-resolution progress on a queued item.
    func setResolveAttempt(_ attempt: ResolveAttempt, for videoId: String) {
        guard let idx = queue.firstIndex(where: { $0.videoId == videoId }) else { return }
        queue[idx].resolveAttempt = attempt
    }
}
