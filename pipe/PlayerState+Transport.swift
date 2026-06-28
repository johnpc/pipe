import AVFoundation

/// End-of-item advancement, stall recovery, and play() entry point.
extension PlayerState {
    func handlePlaybackEnded() {
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: 0)
        }
        let finishedIndex = currentIndex
        guard finishedIndex >= 0, finishedIndex < queue.count else { return }
        queue.remove(at: finishedIndex)
        persistQueue()
        // Honor an "end of episode" sleep request: stop instead of advancing.
        if stopAfterCurrentEpisode {
            stopAfterCurrentEpisode = false
            currentIndex = queue.isEmpty ? -1 : min(finishedIndex, queue.count - 1)
            stop()
        } else if queue.isEmpty {
            currentIndex = -1
            stop()
        } else {
            // The next item now occupies finishedIndex (clamp for the last item).
            currentIndex = min(finishedIndex, queue.count - 1)
            playItem(queue[currentIndex])
        }
    }

    /// Adopt AVPlayer's real play/pause state when `timeControlStatus` changes,
    /// so an external pause (Picture-in-Picture, lock screen, Control Center) —
    /// which pauses the AVPlayer directly without calling `pause()` — keeps our
    /// `isPlaying` and now-playing info in sync instead of being fought.
    /// Decision is delegated to the pure `PlaybackStatusPolicy` for testability.
    func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        let nowPlaying = PlaybackStatusPolicy.isPlaying(for: status, current: isPlaying)
        guard nowPlaying != isPlaying else { return }
        isPlaying = nowPlaying
        updateNowPlaying()
    }

    /// Recover from an involuntary buffer-underrun stall (surfaced by the
    /// `AVPlayerItemPlaybackStalled` notification, not by `.paused`). Only nudge
    /// when we still intend to be playing — a user/external pause leaves
    /// `isPlaying` false, so this is a no-op then.
    func handlePlaybackStalled() {
        guard isPlaying else { return }
        player?.play()
        if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
    }

    func play(videoId: String, urlString: String, audioUrl: String = "", title: String?, artist: String?, thumbnail: String?, duration: Int = 0, uploadedDate: String? = nil) {
        let item = QueueItem(videoId: videoId, title: title ?? "", artist: artist ?? "", thumbnail: thumbnail ?? "", url: urlString, audioUrl: audioUrl, duration: duration, uploadedDate: uploadedDate)
        queue.insert(item, at: 0)
        playIndex(0)
    }

    /// Jump to a video at a specific start time (used for chapter navigation).
    /// Seeks in place if it's already the current item; otherwise starts it at
    /// the given offset.
    func jumpTo(videoId: String, url: String, audioUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int, startAt: Double) {
        if currentVideoId == videoId, player != nil {
            seek(to: startAt)
            if !isPlaying { resume() }
            return
        }
        pendingSeek = startAt
        play(videoId: videoId, urlString: url, audioUrl: audioUrl, title: title, artist: artist, thumbnail: thumbnail, duration: duration)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        defaults.set(speed, forKey: speedKey)
        if isPlaying { player?.rate = speed }
        updateNowPlaying()
    }
}
