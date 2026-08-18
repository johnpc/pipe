import AVFoundation

/// Player observer wiring: install the time/end/stall/status/error observers on
/// the freshly built `player`, and tear them all down. Split out of +Engine to
/// keep each file focused (and under the line limit).
extension PlayerState {
    func installPlaybackObservers() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.handleProgress(currentTime: time.seconds, itemDuration: self?.player?.currentItem?.duration.seconds)
        }

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.handlePlaybackEnded()
        }

        // A stream that dies mid-play (expired/truncated) posts this rather than
        // playing to its end — surface it instead of failing silently.
        failedEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self?.log.event("itemError", "failedToPlayToEnd", fields: ["error": err?.localizedDescription ?? "unknown"])
            self?.handlePrematureEnd()
        }

        // Recover from involuntary stalls (audio stream buffer underruns) that
        // otherwise leave playback frozen until the user manually seeks.
        stallObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.log.event("stall", "playbackStalled", fields: ["at": String(Int(self?.currentTime ?? 0))])
            self?.handlePlaybackStalled()
        }

        // Adopt the player's real play/pause state so external pauses (PiP, lock
        // screen, Control Center) stay in sync with our UI.
        statusObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.handleTimeControlStatus(p.timeControlStatus) }
        }

        // A failed AVPlayerItem is otherwise silent: log its error, then recover.
        // Without the recovery the item just sits at 0s forever — a dead-on-arrival
        // URL is unplayable, so only a freshly resolved one can succeed.
        itemStatusObserver = player?.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .failed:
                let itemError = item.error
                Task { @MainActor in
                    self?.log.event("itemError", "itemFailed", fields: ["error": itemError?.localizedDescription ?? "unknown"])
                    self?.handleItemFailure(error: itemError)
                }
            case .readyToPlay:
                Task { @MainActor in self?.noteItemPlaying() }
            default:
                break
            }
        }
    }

    /// Tear down all player observers. Shared by `playItem` (before building a
    /// new player) and `stop()`.
    func teardownPlaybackObservers() {
        if let old = timeObserver, let p = player { p.removeTimeObserver(old); timeObserver = nil }
        if let old = endObserver { NotificationCenter.default.removeObserver(old); endObserver = nil }
        if let old = failedEndObserver { NotificationCenter.default.removeObserver(old); failedEndObserver = nil }
        if let old = stallObserver { NotificationCenter.default.removeObserver(old); stallObserver = nil }
        statusObserver?.invalidate(); statusObserver = nil
        itemStatusObserver?.invalidate(); itemStatusObserver = nil
        removeSponsorObserver()
    }
}
