import Foundation
import AVFoundation

/// Re-resolves an item's stream URLs from its videoId when the stored URL is
/// stale/expired, then plays the fresh URL. This fixes both the "paused
/// overnight won't resume" and "long video ends early" symptoms, which share a
/// root cause: time-limited googlevideo URLs captured at enqueue time.
extension PlayerState {
    func refreshAndPlay(_ item: QueueItem) {
        // Reflect the now-playing metadata immediately so the UI isn't blank
        // while we fetch (playback itself starts once the fresh URL arrives).
        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        log.event("play", "refreshing stale url", fields: ["videoId": item.videoId])

        Task { [weak self] in
            guard let self else { return }
            let refreshed = await Self.reresolve(item)
            await MainActor.run {
                // Bail if the user moved on to a different item meanwhile.
                guard self.currentVideoId == item.videoId else { return }
                if let refreshed {
                    self.updateQueueItem(refreshed)
                    self.playItem(refreshed, skipRefresh: true)
                } else {
                    // Re-resolution failed (offline/instance down): fall back to
                    // the stored URL so a still-valid URL or the error path both
                    // behave as before.
                    self.log.event("play", "refresh failed, using stored url", fields: ["videoId": item.videoId])
                    self.playItem(item, skipRefresh: true)
                }
            }
        }
    }

    /// Fetch fresh streams and return a copy of `item` with updated URLs and a
    /// current `resolvedAt`, or nil if the fetch/decoding fails. Bypasses the
    /// stream cache: this path exists to mint a NEW URL (expired or dead on
    /// arrival) — re-serving the cached one would fail identically.
    static func reresolve(_ item: QueueItem) async -> QueueItem? {
        guard let response = try? await PipedAPI.streams(item.videoId, bypassingCache: true) else { return nil }
        var copy = item
        copy.url = getStreamUrl(response)
        copy.audioUrl = getAudioStreamUrl(response)
        copy.castUrl = getCastStreamUrl(response)
        copy.resolvedAt = Date()
        guard !copy.url.isEmpty || !copy.audioUrl.isEmpty else { return nil }
        return copy
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
        teardownPlaybackObservers()
        releaseCurrentPlayer()
        teardownCast()
        isPlaying = false
        isBuffering = false
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
