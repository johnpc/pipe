import AVFoundation
import MediaPlayer

/// Audio-session event handling: pause/resume around interruptions (calls, Siri)
/// and pause when headphones are unplugged. Decisions live in the pure
/// `AudioSessionPolicy`; this wires the notifications to the player.
extension PlayerState {
    func observeAudioSession() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            log.event("interruption", "began", fields: ["wasPlaying": String(isPlaying)])
            pause()
        case .ended:
            let opts = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let willResume = AudioSessionPolicy.shouldResumeAfterInterruption(optionsRawValue: opts, wasPlaying: wasPlayingBeforeInterruption)
            log.event("interruption", "ended", fields: ["resume": String(willResume)])
            if willResume {
                setupAudioSession()
                resume()
            }
        @unknown default:
            break
        }
    }

    @objc func handleRouteChange(_ note: Notification) {
        guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
        if AudioSessionPolicy.shouldPauseOnRouteChange(reasonRawValue: reason) {
            log.event("route", "pause on change", fields: ["reason": String(reason)])
            pause()
        }
    }

    func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        cmd.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cmd.skipForwardCommand.preferredIntervals = [10]
        cmd.skipForwardCommand.addTarget { [weak self] _ in self?.skip(10); return .success }
        cmd.skipBackwardCommand.preferredIntervals = [10]
        cmd.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(-10); return .success }
        cmd.nextTrackCommand.addTarget { [weak self] _ in self?.playNext(); return .success }
        cmd.previousTrackCommand.addTarget { [weak self] _ in self?.playPrevious(); return .success }
        // Lock-screen / Control Center scrubbing.
        cmd.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

}
