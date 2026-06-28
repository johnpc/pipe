import AVFoundation
import MediaPlayer

/// Core playback engine for PlayerState: load item, observers, progress,
/// chapters, end-of-item, stall recovery.
extension PlayerState {
    func playItem(_ item: QueueItem) {
        error = nil
        setupAudioSession()

        // Prefer a downloaded local file (offline playback) over streaming.
        let source = downloads?.localURLString(for: item.videoId) ?? item.playbackURL(videoMode: videoMode)
        guard let url = URL(string: source) else {
            error = "Couldn't play \(item.title)"
            return
        }

        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentTime = 0
        duration = 0
        updateCurrentChapter(for: item.videoId, at: 0)
        
        teardownPlaybackObservers()

        player = AVPlayer(url: url)

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.handleProgress(currentTime: time.seconds, itemDuration: self?.player?.currentItem?.duration.seconds)
        }

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.handlePlaybackEnded()
        }

        // Recover from involuntary stalls (audio stream buffer underruns) that
        // otherwise leave playback frozen until the user manually seeks.
        stallObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.handlePlaybackStalled()
        }

        // Adopt the player's real play/pause state so external pauses (PiP, lock
        // screen, Control Center) stay in sync with our UI.
        statusObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.handleTimeControlStatus(p.timeControlStatus) }
        }
        
        // Resume from saved position
        let savedPos = recents?.getTimestamp(videoId: item.videoId) ?? 0
        
        // Add to recents
        recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)
        
        // A pending chapter seek takes precedence over the saved-resume position.
        if let target = pendingSeek {
            pendingSeek = nil
            currentTime = target
            player?.seek(to: CMTime(seconds: target, preferredTimescale: 1))
        } else if savedPos > 10 {
            player?.seek(to: CMTime(seconds: savedPos, preferredTimescale: 1))
        }

        player?.play()
        // Apply the remembered playback speed to the new item.
        if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
        isPlaying = true
        updateNowPlaying()
    }
    
    /// Tear down all player observers (time, end-of-item, stall, status). Shared
    /// by `playItem` (before building a new player) and `stop()`.
    func teardownPlaybackObservers() {
        if let old = timeObserver, let p = player { p.removeTimeObserver(old); timeObserver = nil }
        if let old = endObserver { NotificationCenter.default.removeObserver(old); endObserver = nil }
        if let old = stallObserver { NotificationCenter.default.removeObserver(old); stallObserver = nil }
        statusObserver?.invalidate(); statusObserver = nil
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
    }
}
