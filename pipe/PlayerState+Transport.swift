import AVFoundation
import Combine

/// End-of-item advancement and stall/status recovery. (`stop()` lives with the
/// teardown helpers in +Refresh.)
extension PlayerState {
    func handlePlaybackEnded() {
        // Distinguish a genuine finish from a stream that died early (the
        // "1-hour video ends at 30 min" bug). Recover in place when premature.
        let outcome = EndOfItemPolicy.outcome(reached: currentTime, expected: expectedDuration, retries: prematureEndRetries)
        log.event("end", "fired", fields: [
            "reached": String(Int(currentTime)),
            "expected": expectedDuration.map { String(Int($0)) } ?? "unknown",
            "outcome": "\(outcome)",
        ])
        if outcome != .finished { handlePrematureEnd(giveUp: outcome == .giveUp); return }
        prematureEndRetries = 0
        advanceAfterFinish()
    }

    /// A premature end: reload the current item from its last position to keep
    /// playing, or (out of retries) fall through to a normal advance.
    func handlePrematureEnd(giveUp: Bool = false) {
        let outcome = EndOfItemPolicy.outcome(reached: currentTime, expected: expectedDuration, retries: prematureEndRetries)
        guard !giveUp, outcome == .recover, currentIndex >= 0, currentIndex < queue.count else {
            prematureEndRetries = 0
            advanceAfterFinish()
            return
        }
        prematureEndRetries += 1
        log.event("end", "recover reload", fields: ["attempt": String(prematureEndRetries), "from": String(Int(currentTime))])
        pendingSeek = currentTime
        // Force a fresh stream URL on recovery: a premature end is usually an
        // expired URL, so reloading the same one would just fail again. Marking
        // it stale makes playItem re-resolve from the videoId.
        queue[currentIndex].resolvedAt = nil
        playItem(queue[currentIndex])
    }

    /// Mark the finished item complete, drop it from the queue, and advance
    /// (honoring an "end of episode" sleep request).
    func advanceAfterFinish() {
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: 0)
        }
        let finishedIndex = currentIndex
        guard finishedIndex >= 0, finishedIndex < queue.count else { return }
        queue.remove(at: finishedIndex)
        persistQueue()
        if stopAfterCurrentEpisode {
            stopAfterCurrentEpisode = false
            currentIndex = queue.isEmpty ? -1 : min(finishedIndex, queue.count - 1)
            stop()
        } else if queue.isEmpty {
            currentIndex = -1
            stop()
        } else {
            // The next item now occupies finishedIndex (clamp for the last item).
            currentIndex = min(finishedIndex, queue.count - 1)
            playItem(queue[currentIndex])
        }
    }

    /// Adopt AVPlayer's real play/pause state when `timeControlStatus` changes,
    /// so an external pause (Picture-in-Picture, lock screen, Control Center) —
    /// which pauses the AVPlayer directly without calling `pause()` — keeps our
    /// `isPlaying` and now-playing info in sync instead of being fought.
    /// Decision is delegated to the pure `PlaybackStatusPolicy` for testability.
    func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        // Surface (re)buffering: waiting means "intends to play, no audio yet";
        // reaching .playing or .paused ends it.
        isBuffering = status == .waitingToPlayAtSpecifiedRate
        let nowPlaying = PlaybackStatusPolicy.isPlaying(for: status, current: isPlaying)
        guard nowPlaying != isPlaying else { return }
        log.event("status", "adopt", fields: ["raw": String(status.rawValue), "from": String(isPlaying), "to": String(nowPlaying)])
        isPlaying = nowPlaying
        updateNowPlaying()
    }

    /// Recover from an involuntary buffer-underrun stall (surfaced by the
    /// `AVPlayerItemPlaybackStalled` notification, not by `.paused`). Only nudge
    /// when we still intend to be playing — a user/external pause leaves
    /// `isPlaying` false, so this is a no-op then.
    func handlePlaybackStalled() {
        guard isPlaying else { return }
        player?.playImmediately(atRate: playbackSpeed)
    }

}
