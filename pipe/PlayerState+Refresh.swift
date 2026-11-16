import Foundation
import AVFoundation

/// Re-resolves an item's stream URLs from its videoId when the stored URL is
/// stale, expired, or dead, then plays the fresh URL. This fixes both the
/// "paused overnight won't resume" and "long video ends early" symptoms, which
/// share a root cause: time-limited googlevideo URLs captured at enqueue time.
/// The lifecycle is already in `.resolving` when this runs (see +Engine).
extension PlayerState {
    func refreshAndPlay(_ item: QueueItem) {
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
                // Bail if the user moved on to a different item meanwhile.
                guard self.currentVideoId == item.videoId else { return }
                if let refreshed {
                    self.updateQueueItem(refreshed)
                    self.playItem(refreshed, refresh: .never)
                } else {
                    // Re-resolution failed (offline/instance down): fall back to
                    // the stored URL so a still-valid URL or the error path both
                    // behave as before.
                    self.log.event("play", "refresh failed, using stored url", fields: ["videoId": item.videoId])
                    self.playItem(item, refresh: .never)
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
    /// next playback session.
    func stop() {
        playGeneration += 1  // an in-flight async load (HLS/composed) must not revive playback
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
