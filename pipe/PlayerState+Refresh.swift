import Foundation
import AVFoundation

/// The lifecycle's `resolve` effect: fetch fresh stream URLs for an item from
/// its videoId (stale, expired, or dead on arrival), then report back with the
/// generation the fetch started under so a superseded load is ignored. This
/// fixes both the "paused overnight won't resume" and "long video ends early"
/// symptoms, which share a root cause: time-limited googlevideo URLs captured
/// at enqueue time.
extension PlayerState {
    func resolveAndPlay(_ item: QueueItem, generation: Int) {
        // Reflect the now-playing metadata immediately so the UI isn't blank
        // while we fetch (playback itself starts once the fresh URL arrives).
        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        log.event("play", "refreshing stale url", fields: ["videoId": item.videoId])

        let resolver = self.resolver
        Task { [weak self] in
            let refreshed = await resolver.fresh(item)
            await MainActor.run {
                guard let self else { return }
                if let refreshed {
                    self.apply(.resolved(item: refreshed, generation: generation))
                } else {
                    // Re-resolution failed (offline/instance down): the stored URL
                    // is tried as-is, so a still-valid URL or the error path both
                    // behave as before.
                    self.log.event("play", "refresh failed, using stored url", fields: ["videoId": item.videoId])
                    self.apply(.resolveFailed(item: item, generation: generation))
                }
            }
        }
    }

    /// Persist refreshed URLs back into the queue so we don't refetch next time.
    func updateQueueItem(_ item: QueueItem) {
        guard let idx = queue.firstIndex(where: { $0.videoId == item.videoId }) else { return }
        queue[idx] = item
        persistQueue()
    }

    /// Pause and drop the current AVPlayer so it stops producing audio. Observers
    /// must already be torn down (they hold time observers on this player).
    func releaseCurrentPlayer() {
        guard let old = player else { return }
        old.pause()
        player = nil
    }

    /// Full stop: tear everything down and clear all item-scoped state so
    /// nothing (sponsor segments, expected duration, video id) leaks into the
    /// next playback session. The lifecycle bumps its generation, so an
    /// in-flight async load cannot revive playback.
    func stop() {
        apply(.stop)
        teardownPlaybackObservers()
        releaseCurrentPlayer()
        teardownCast()
        currentTitle = nil
        currentArtist = nil
        currentThumbnail = nil
        currentVideoId = nil
        currentTime = 0
        duration = 0
        expectedDuration = nil
        sponsorSegments = []
        currentChapterTitle = nil
    }
}
