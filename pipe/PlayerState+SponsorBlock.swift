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
        player?.seek(to: CMTime(seconds: target, preferredTimescale: 1))
        currentTime = target
    }

    func removeSponsorObserver() {
        if let o = sponsorObserver, let p = player { p.removeTimeObserver(o); sponsorObserver = nil }
    }
}
