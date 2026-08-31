import AVFoundation

/// SponsorBlock integration: fetch a video's skip segments and auto-seek past
/// them during playback. The skip decision is delegated to the pure
/// `SponsorBlockLogic` so it stays unit-testable.
extension PlayerState {
    /// Fetch segments for the now-playing item and install the skip observer.
    /// Called from `playItem` after the player is built. No-ops cheaply when the
    /// fetch returns nothing (the common case: most videos have no segments).
    func loadSponsorSegments(for videoId: String) {
        sponsorSegments = []
        Task { [weak self] in
            let segments = await PipedAPI.sponsorSegments(videoId)
            await MainActor.run {
                guard let self, self.currentVideoId == videoId else { return }
                self.sponsorSegments = segments
                self.log.event("sponsor", "loaded", fields: ["count": String(segments.count), "videoId": videoId])
                self.installSponsorObserver()
            }
        }
    }

    /// Observe playback time on a 1s cadence (independent of the 5s progress
    /// observer) and skip to the end of any segment we're inside.
    func installSponsorObserver() {
        removeSponsorObserver()
        guard !sponsorSegments.isEmpty else { return }
        sponsorObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main
        ) { [weak self] time in
            self?.applySponsorSkip(at: time.seconds)
        }
    }

    /// Seek past a sponsor segment covering `time`, if skipping is enabled.
    /// Extracted so the decision is driven by the tested `SponsorBlockLogic`.
    func applySponsorSkip(at time: Double) {
        guard let target = SponsorBlockLogic.skipTarget(at: time, in: sponsorSegments, enabled: sponsorBlockEnabled) else { return }
        log.event("sponsor", "skip", fields: ["from": String(Int(time)), "to": String(Int(target))])
        // Seek precisely (sub-second timescale, zero tolerance) to the segment's
        // fractional end. A 1s timescale truncated `target` back inside the
        // segment, so the 1s observer re-fired the skip forever — a seek storm
        // (~25/s) that stuttered playback and flooded diagnostics.
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            // A seek can leave the player paused (rate drops to 0), which stranded
            // playback at the segment end. Re-assert play + speed if we still
            // intend to be playing.
            guard let self, self.isPlaying else { return }
            self.player?.playImmediately(atRate: self.playbackSpeed)
        }
        currentTime = target
    }

    func removeSponsorObserver() {
        if let o = sponsorObserver, let p = player { p.removeTimeObserver(o); sponsorObserver = nil }
    }
}
