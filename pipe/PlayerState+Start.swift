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

        // Resume from saved position; a live stream is neither resumed nor remembered.
        let savedPos = RecentsPolicy.records(item) ? (recents?.getTimestamp(videoId: item.videoId) ?? 0) : 0

        // Add to recents
        if RecentsPolicy.records(item) {
            recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)
        }

        // A requested start position (chapter jump, recovery, mode switch) takes
        // precedence over the saved-resume position. `.playerStarted` consumes it.
        if let target = lifecycle.startAt {
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
        apply(.playerStarted)  // .buffering until timeControlStatus reports .playing
        updateNowPlaying()
    }
}
