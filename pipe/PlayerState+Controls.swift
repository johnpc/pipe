import AVFoundation

/// Transport controls invoked by the UI and remote commands: play/pause, skip,
/// seek, and chapter jumps.
extension PlayerState {
    func togglePlayPause() { if isPlaying { pause() } else { resume() } }

    func resume() {
        // After a cold launch the queue is restored but no AVPlayer exists yet;
        // start the current item instead of a silent no-op.
        if player == nil, currentIndex >= 0, currentIndex < queue.count {
            playItem(queue[currentIndex])
            return
        }
        player?.play()
        if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
        isPlaying = true
        log.event("transport", "resume", fields: ["at": String(Int(currentTime))])
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        log.event("transport", "pause", fields: ["at": String(Int(currentTime))])
        updateNowPlaying()
    }

    func play(videoId: String, urlString: String, audioUrl: String = "", title: String?, artist: String?, thumbnail: String?, duration: Int = 0, uploadedDate: String? = nil) {
        let item = QueueItem(videoId: videoId, title: title ?? "", artist: artist ?? "", thumbnail: thumbnail ?? "", url: urlString, audioUrl: audioUrl, duration: duration, uploadedDate: uploadedDate)
        queue.insert(item, at: 0)
        playIndex(0)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        defaults.set(speed, forKey: speedKey)
        if isPlaying { player?.rate = speed }
        updateNowPlaying()
    }

    func skip(_ seconds: Double) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }

    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        log.event("transport", "seek", fields: ["from": String(Int(currentTime)), "to": String(Int(time))])
        currentTime = time
        updateNowPlaying()
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
}
