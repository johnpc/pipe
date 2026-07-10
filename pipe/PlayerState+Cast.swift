import Foundation
import Combine

/// Cast handoff: when a receiver is connected, playback and transport drive the
/// TV instead of the local `AVPlayer`. Kept in its own file so the branch logic
/// is isolated and the transport files stay focused.
extension PlayerState {
    /// True when a TV session is live and should own playback.
    var isCasting: Bool { cast?.isCasting == true }

    /// Inject the cast store and watch its connection. When a receiver connects,
    /// the currently-playing item is handed off to the TV at its current
    /// position — so any entry point (the full-player button, a row's Cast
    /// action) results in "what I'm playing jumps to the TV". Cancels local
    /// playback as part of the handoff.
    func attachCast(_ store: CastStore) {
        cast = store
        // Only hand off on the actual transition INTO connected. `connectionState`
        // is republished on every receiver status callback; without
        // removeDuplicates() the sink re-fired ~15×/sec, each castItem() aborting
        // the previous loadMedia ("replaced") so the video never finished loading
        // and every transport press was wiped by the next reload.
        castConnectionCancellable = store.$connectionState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self, state == .connected,
                      self.currentIndex >= 0, self.currentIndex < self.queue.count,
                      self.currentVideoId != nil else { return }
                self.castItem(self.queue[self.currentIndex])
            }
    }

    /// Send the item to the receiver, tearing down local playback so audio never
    /// plays on both phone and TV. Publishes now-playing metadata immediately and
    /// mirrors the receiver's clock back onto `currentTime`. Resumes from the
    /// saved position, matching local playback.
    func castItem(_ item: QueueItem) {
        guard let cast else { return }
        // Guard against reloading the item already loaded on the receiver — a
        // redundant loadMedia aborts the in-flight one and restarts playback.
        if castLoadedVideoId == item.videoId { return }
        castLoadedVideoId = item.videoId
        teardownPlaybackObservers()
        releaseCurrentPlayer()

        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        duration = item.duration > 0 ? Double(item.duration) : 0
        let savedPos = recents?.getTimestamp(videoId: item.videoId) ?? 0
        currentTime = savedPos
        recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)

        log.event("cast", "load", fields: ["videoId": item.videoId, "from": String(Int(savedPos))])
        cast.load(CastLogic.media(from: item, startTime: savedPos))
        isPlaying = true
        observeCastTime(cast)
        updateNowPlaying()
    }

    /// Stop the receiver session and clear cast state. Called from `stop()`.
    func teardownCast() {
        if isCasting { cast?.stop() }
        castTimeCancellable?.cancel()
        castTimeCancellable = nil
        castLoadedVideoId = nil
    }

    /// Subscribe to the receiver's clock so the phone's scrubber and saved
    /// progress track the TV. Cancels any prior subscription first.
    private func observeCastTime(_ cast: CastStore) {
        castTimeCancellable?.cancel()
        castTimeCancellable = cast.$currentTime.sink { [weak self] time in
            guard let self, self.isCasting else { return }
            self.currentTime = time
            if let vid = self.currentVideoId { self.recents?.updateTimestamp(videoId: vid, timestamp: time) }
        }
    }
}
