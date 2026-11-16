import AVFoundation
import Combine

/// End-of-item advancement and stall/status recovery. (`stop()` lives with the
/// teardown helpers in +Refresh.) The lifecycle decides; this logs and feeds it.
extension PlayerState {
    /// The item played to its end — or claimed to. A truncated/expired stream
    /// fires this far short of the real duration (the "1-hour video ends at
    /// 30 min" bug); the lifecycle then reloads in place instead of advancing.
    func handlePlaybackEnded() {
        let outcome = EndOfItemPolicy.outcome(reached: currentTime, expected: expectedDuration, retries: prematureEndRetries)
        log.event("end", "fired", fields: [
            "reached": String(Int(currentTime)),
            "expected": expectedDuration.map { String(Int($0)) } ?? "unknown",
            "outcome": "\(outcome)",
        ])
        if outcome == .recover {
            // Recovery re-resolves the (likely expired) URL rather than
            // reloading the dead one, and resumes from where it died.
            log.event("end", "recover reload", fields: ["attempt": String(prematureEndRetries + 1), "from": String(Int(currentTime))])
        }
        let item = currentIndex >= 0 && currentIndex < queue.count ? queue[currentIndex] : nil
        apply(.ended(item: item, reached: currentTime, expected: expectedDuration))
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
    /// phase and now-playing info in sync instead of being fought.
    func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        let before = phase
        apply(.status(status))
        guard phase != before else { return }
        log.event("status", "adopt", fields: ["raw": String(status.rawValue), "from": before.label, "to": phase.label])
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
