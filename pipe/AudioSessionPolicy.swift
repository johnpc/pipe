import AVFoundation

/// Pure decisions for audio-session events, so the behavior is unit-testable
/// without a real AVAudioSession.
enum AudioSessionPolicy {
    /// On an interruption ending, whether to resume: only when the system says
    /// it's appropriate (the `.shouldResume` option) and we were playing before.
    static func shouldResumeAfterInterruption(optionsRawValue: UInt, wasPlaying: Bool) -> Bool {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRawValue)
        return wasPlaying && options.contains(.shouldResume)
    }

    /// On a route change, whether to pause: when the old output became
    /// unavailable (e.g. headphones unplugged) — the iOS HIG expectation.
    static func shouldPauseOnRouteChange(reasonRawValue: UInt) -> Bool {
        AVAudioSession.RouteChangeReason(rawValue: reasonRawValue) == .oldDeviceUnavailable
    }
}
