import Foundation

/// Recovery from a *load-time* item failure (`AVPlayerItem.status == .failed`),
/// which otherwise leaves playback frozen at 0s with only a log line.
///
/// Split from +Transport (premature end) because the two failures need opposite
/// treatment: a premature end resumes from where it died, whereas an item that
/// never loaded has no position to keep and simply needs a fresh URL.
extension PlayerState {
    /// A stream that failed to load: mint a new URL and retry, or give up and
    /// surface the error. The stored URL is dead, so re-resolving from the
    /// videoId is the only move that can succeed.
    func handleItemFailure(error itemError: Error? = nil) {
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        let isLocal = downloads?.localURLString(for: item.videoId) != nil
        let outcome = ItemFailurePolicy.outcome(retries: itemFailureRetries, isLocal: isLocal)
        log.event("itemError", "recovery", fields: [
            "videoId": item.videoId,
            "attempt": String(itemFailureRetries),
            "outcome": "\(outcome)",
        ])
        guard outcome == .retry else {
            itemFailureRetries = 0
            let reason = ItemFailurePolicy.reason(from: itemError)
            // Log the real cause we're about to show, so a give-up is diagnosable
            // from the exported/uploaded log without guessing.
            log.event("itemError", "giveUp", fields: ["videoId": item.videoId, "reason": reason])
            error = ItemFailurePolicy.failureMessage(title: item.title, reason: reason)
            isPlaying = false
            return
        }
        itemFailureRetries += 1
        // Force a fresh URL: the stored one is dead on arrival, so replaying it
        // would fail identically. Marking it stale makes playItem re-resolve.
        queue[currentIndex].resolvedAt = nil
        playItem(queue[currentIndex])
    }

    /// Clear the retry budget once an item genuinely starts playing, so a later
    /// failure on a different item gets a full set of attempts.
    func noteItemPlaying() {
        guard itemFailureRetries != 0 else { return }
        itemFailureRetries = 0
    }
}
