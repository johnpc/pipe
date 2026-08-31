import Foundation

/// Restores the user's persisted playback preferences at init: speed,
/// SponsorBlock, and audio/video mode.
extension PlayerState {
    func restorePreferences() {
        // Restore the user's preferred playback speed (podcast-app behavior).
        let savedSpeed = defaults.float(forKey: speedKey)
        if savedSpeed > 0 { playbackSpeed = savedSpeed }
        // Default ON; only an explicit stored `false` disables it.
        if defaults.object(forKey: sponsorKey) != nil { sponsorBlockEnabled = defaults.bool(forKey: sponsorKey) }
        // Restore the audio/video mode choice (a video-first user shouldn't have
        // to re-enable video every launch).
        videoMode = defaults.bool(forKey: videoModeKey)
    }
}
