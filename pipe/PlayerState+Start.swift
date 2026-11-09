import AVFoundation

/// Final stage of loading an item: install the built `AVPlayer`, wire its
/// observers, apply the resume position, and start playback. Shared by the
/// single-stream and composed paths (see +Engine / +Composed).
extension PlayerState {
    func startPlayer(_ avPlayer: AVPlayer, for item: QueueItem) {
        player = avPlayer
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

        // Start the instant any media is buffered rather than waiting for
        // AVPlayer's default anti-stall margin — several silent seconds on a
        // proxied stream. The stall observer already recovers any underruns
        // this more eager start produces.
        player?.playImmediately(atRate: playbackSpeed)
        isPlaying = true
        isBuffering = true  // cleared when timeControlStatus first hits .playing
        updateNowPlaying()
    }
}
