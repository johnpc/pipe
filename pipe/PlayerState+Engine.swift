import AVFoundation
import MediaPlayer

/// Core playback engine for PlayerState. `playItem` only decides whether the
/// item's URLs need refreshing and hands the item to the lifecycle; the
/// lifecycle then asks for a resolve, a build, or a cast hand-off (see
/// +Lifecycle). `buildPlayer` is the build: local file, native HLS, composed
/// video + audio, or a single stream.
extension PlayerState {
    /// `casting` overrides the live `isCasting` check for the hand-off that
    /// runs inside the connection publisher, which fires before the store's
    /// state has changed.
    func playItem(_ item: QueueItem, refresh: RefreshMode = .ifStale, casting: Bool? = nil) {
        error = nil
        let isLocal = downloads?.localURLString(for: item.videoId) != nil
        // Stream URLs are time-limited; re-resolve a stale (or known-dead) one
        // before playing so an item paused overnight doesn't load a dead URL.
        // Local files never expire. (Applies to the TV too: the receiver
        // fetches the URL directly, so a stale one would fail there as well.)
        let needsRefresh = StreamFreshness.shouldRefresh(refresh, resolvedAt: item.resolvedAt, now: Date(), isLocal: isLocal)
        apply(.load(item: item, refresh: needsRefresh, casting: casting ?? isCasting))
    }

    /// Build a local player for `item` and start it. Async paths (HLS master
    /// read, composed tracks) finish only if `generation` is still current.
    func buildPlayer(for item: QueueItem, generation: Int) {
        let isLocal = downloads?.localURLString(for: item.videoId) != nil
        setupAudioSession()

        // YouTube's own HLS playlist, when offered, is the durable way to play:
        // it keeps working when direct googlevideo URLs are culled (see +HLS).
        if HLSPlaybackLogic.usesHLS(item, isLocal: isLocal) {
            beginItem(item, isLocal: isLocal)
            startHLS(item, generation: generation)
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
            startComposed(item, pair: pair, fallback: url, generation: generation)
        } else {
            startPlayer(AVPlayer(url: url), for: item)
        }
    }

    /// Publish the item's metadata, reset per-item state, and retire the
    /// previous player, so the UI reflects the new item even while its stream
    /// is still being prepared.
    func beginItem(_ item: QueueItem, isLocal: Bool) {
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
