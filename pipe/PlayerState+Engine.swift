import AVFoundation
import MediaPlayer

/// Core playback engine for PlayerState: decide how an item loads (fresh URL,
/// cast receiver, native HLS, composed video + audio, or a single stream) and
/// reset the item-scoped state. Every branch reports where it is to the
/// lifecycle (`apply`), which owns the phase and the background hold.
/// Starting the built player lives in +Start, the composed path in +Composed;
/// end-of-item, stall, and status handling in +Transport.
extension PlayerState {
    func playItem(_ item: QueueItem, refresh: RefreshMode = .ifStale) {
        error = nil
        let isLocal = downloads?.localURLString(for: item.videoId) != nil

        // Stream URLs are time-limited; re-resolve a stale (or known-dead) one
        // before playing so an item paused overnight doesn't load a dead URL.
        // Local files never expire. (Applies to the TV too: the receiver
        // fetches the URL directly, so a stale one would fail there as well.)
        if StreamFreshness.shouldRefresh(refresh, resolvedAt: item.resolvedAt, now: Date(), isLocal: isLocal) {
            apply(.load(videoId: item.videoId, refresh: true, casting: false))
            refreshAndPlay(item)
            return
        }

        // A connected receiver owns playback: hand it the video and skip
        // building a local AVPlayer entirely.
        if isCasting {
            castItem(item)
            return
        }

        apply(.load(videoId: item.videoId, refresh: false, casting: false))
        setupAudioSession()

        // YouTube's own HLS playlist, when offered, is the durable way to play:
        // it keeps working when direct googlevideo URLs are culled (see +HLS).
        if HLSPlaybackLogic.usesHLS(item, isLocal: isLocal) {
            beginItem(item, isLocal: isLocal)
            startHLS(item)
            return
        }

        // Prefer a downloaded local file (offline playback) over streaming.
        let source = downloads?.localURLString(for: item.videoId) ?? item.playbackURL(videoMode: videoMode)
        guard let url = URL(string: source) else {
            log.event("play", "bad url", fields: ["videoId": item.videoId, "result": "failed"])
            apply(.unplayable(title: item.title))
            return
        }

        beginItem(item, isLocal: isLocal)

        // Video mode pairs the video-only track with the chosen audio track so
        // the audio language applies there too; `url` (the muxed stream) is the
        // fallback if the pair can't be loaded.
        if let pair = ComposedPlaybackLogic.pair(for: item, videoMode: videoMode, isLocal: isLocal) {
            startComposed(item, pair: pair, fallback: url)
        } else {
            startPlayer(AVPlayer(url: url), for: item)
        }
    }

    /// Publish the item's metadata, reset per-item state, and retire the
    /// previous player, so the UI reflects the new item even while its stream
    /// is still being prepared.
    func beginItem(_ item: QueueItem, isLocal: Bool) {
        playGeneration += 1
        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentTime = 0
        // Seed duration from the Piped-reported length so the lock screen shows a
        // total time (and a working progress bar) immediately, instead of a blank
        // until AVPlayer loads its own duration on the first progress tick.
        duration = item.duration > 0 ? Double(item.duration) : 0
        lastHeartbeatBucket = -1
        expectedDuration = item.duration > 0 ? Double(item.duration) : nil
        updateCurrentChapter(for: item.videoId, at: 0)

        // Fully retire the previous player before building a new one; otherwise
        // the old AVPlayer (still retained by the video view) keeps playing and
        // two items overlap in audio. Teardown alone only removes observers.
        teardownPlaybackObservers()
        releaseCurrentPlayer()

        log.event("play", "start", fields: [
            "videoId": item.videoId,
            "source": isLocal ? "local" : "stream",
            "expectedDuration": String(item.duration),
        ])
    }
}
