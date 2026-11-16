import Foundation

/// Recovery from a *load-time* item failure (`AVPlayerItem.status == .failed`),
/// which otherwise leaves playback frozen at 0s with only a log line.
///
/// Distinct from a premature end (+Transport): a premature end resumes from
/// where it died, whereas an item that never loaded has no position to keep
/// and simply needs a fresh URL. The decision (retry vs give up) is the
/// lifecycle's; this logs it and feeds the event in.
extension PlayerState {
    /// A stream that failed to load: mint a new URL and retry, or give up and
    /// surface the error. The stored URL is dead, so re-resolving from the
    /// videoId is the only move that can succeed.
    func handleItemFailure(error itemError: Error? = nil) {
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        let isLocal = downloads?.localURLString(for: item.videoId) != nil
        let outcome = ItemFailurePolicy.outcome(retries: itemFailureRetries, isLocal: isLocal)
        let reason = ItemFailurePolicy.reason(from: itemError)
        log.event("itemError", "recovery", fields: [
            "videoId": item.videoId,
            "attempt": String(itemFailureRetries),
            "outcome": "\(outcome)",
        ])
        if outcome == .giveUp {
            // Log the real cause we're about to show, so a give-up is diagnosable
            // from the exported/uploaded log without guessing.
            log.event("itemError", "giveUp", fields: ["videoId": item.videoId, "reason": reason])
        }
        apply(.loadFailed(item: item, reason: reason, isLocal: isLocal))
    }

    /// The item genuinely loaded: clear the retry budget so a later failure on
    /// a different item gets a full set of attempts.
    func noteItemPlaying() {
        guard itemFailureRetries != 0 else { return }
        apply(.ready)
    }
}
