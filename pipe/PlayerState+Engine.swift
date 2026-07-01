import AVFoundation
import MediaPlayer

/// Core playback engine for PlayerState: load an item, wire observers, publish
/// progress. End-of-item, stall, and status handling live in +Transport; the
/// observer wiring lives in +Observers.
extension PlayerState {
    func playItem(_ item: QueueItem, skipRefresh: Bool = false) {
        error = nil
        setupAudioSession()

        let isLocal = downloads?.localURLString(for: item.videoId) != nil
        // Stream URLs are time-limited; re-resolve a stale one before playing so
        // an item paused overnight (or a long video whose URL expired) doesn't
        // load a dead URL. Local files never expire.
        if !skipRefresh, StreamFreshness.needsRefresh(resolvedAt: item.resolvedAt, now: Date(), isLocal: isLocal) {
            refreshAndPlay(item)
            return
        }

        // Prefer a downloaded local file (offline playback) over streaming.
        let source = downloads?.localURLString(for: item.videoId) ?? item.playbackURL(videoMode: videoMode)
        guard let url = URL(string: source) else {
            error = "Couldn't play \(item.title)"
            log.event("play", "bad url", fields: ["videoId": item.videoId, "result": "failed"])
            return
        }

        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentTime = 0
        duration = 0
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

        player = AVPlayer(url: url)
        installPlaybackObservers()

        // Fetch + auto-skip SponsorBlock segments for this video.
        loadSponsorSegments(for: item.videoId)

        // Resume from saved position
        let savedPos = recents?.getTimestamp(videoId: item.videoId) ?? 0

        // Add to recents
        recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)

        // A pending chapter seek takes precedence over the saved-resume position.
        if let target = pendingSeek {
            pendingSeek = nil
            currentTime = target
            player?.seek(to: CMTime(seconds: target, preferredTimescale: 1))
            log.event("play", "pendingSeek", fields: ["to": String(Int(target))])
        } else if savedPos > 10 {
            player?.seek(to: CMTime(seconds: savedPos, preferredTimescale: 1))
            log.event("play", "resume", fields: ["from": String(Int(savedPos))])
        }

        player?.play()
        // Apply the remembered playback speed to the new item.
        if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
        isPlaying = true
        updateNowPlaying()
    }

    /// Handle a periodic playback-time update: publish the current time, adopt a
    /// valid item duration, and persist progress. Extracted from the time
    /// observer closure so it is directly unit-testable.
    func handleProgress(currentTime time: Double, itemDuration: Double?) {
        self.currentTime = time
        if let d = itemDuration, d.isFinite, d > 0 { self.duration = d }
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: time)
            updateCurrentChapter(for: vid, at: time)
        }
        logProgressHeartbeat(at: time)
    }
}
