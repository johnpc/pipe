import Foundation

/// Pure decision for what a *load-time* item failure means, so the branchy part
/// is unit-testable without a live AVPlayer.
///
/// `AVPlayerItem.status == .failed` means the item never started — distinct from
/// the premature-end case `EndOfItemPolicy` covers, where playback began and then
/// stopped short. The usual cause is a stream URL that is dead on arrival: the
/// server mints it and it answers 403 to the unbounded range request AVPlayer
/// opens with, so the item fails within a second and playback sits at 0s.
///
/// Retrying the *same* URL cannot help — it's the URL that's bad, not the
/// network — so recovery has to re-resolve from the videoId to mint a new one.
enum ItemFailurePolicy {
    /// Cap on re-resolve attempts before we surface the error. Two fresh URLs is
    /// enough to clear an intermittent bad mint; beyond that the video itself is
    /// unavailable and retrying just spins.
    static let maxRetries = 2

    enum Outcome: Equatable {
        /// Re-resolve the stream URL from the videoId and try again.
        case retry
        /// Out of retries — stop and show the user an error.
        case giveUp
    }

    /// - Parameters:
    ///   - retries: re-resolve attempts already made for this item.
    ///   - isLocal: a downloaded file; its failure is corruption, not a dead URL,
    ///     so re-resolving a remote URL would be the wrong move.
    static func outcome(retries: Int, isLocal: Bool) -> Outcome {
        if isLocal { return .giveUp }
        return retries < maxRetries ? .retry : .giveUp
    }

    /// User-facing copy when recovery is exhausted. Names the item so a failure in
    /// a background queue isn't a mystery, and surfaces the *real* underlying
    /// cause (`reason`) rather than the old "the stream expired" guess — which was
    /// frequently wrong (a dead-on-arrival 403, a throttled instance, and an
    /// offline drop all looked identical to the user).
    static func failureMessage(title: String, reason: String) -> String {
        "Couldn't play \(title) — \(reason)"
    }

    /// Human-readable reason from the `AVPlayerItem.error` behind a load failure.
    /// Pure so the mapping is unit-testable without a live player. Recognizes the
    /// common CoreMedia/HTTP and URL-loading codes; falls back to the error's own
    /// message, then to a generic string when there's no error at all.
    static func reason(from error: Error?) -> String {
        guard let error else { return "playback failed" }
        let ns = error as NSError
        if let http = httpStatus(in: ns) {
            switch http {
            case 403: return "the video server refused the stream (403)"
            case 404: return "the stream is no longer available (404)"
            case 429: return "the video server is rate-limiting (429)"
            default: return "the video server returned an error (\(http))"
            }
        }
        switch (ns.domain, ns.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost):
            return "no connection"
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return "the connection timed out"
        default:
            let message = ns.localizedDescription
            return message.isEmpty ? "playback failed" : message
        }
    }

    /// Dig an HTTP status code out of an NSError chain. AVFoundation buries the
    /// server's response code in an underlying error's userInfo rather than the
    /// top-level code, so walk the `NSUnderlyingErrorKey` chain looking for it.
    private static func httpStatus(in error: NSError) -> Int? {
        var current: NSError? = error
        while let err = current {
            if let code = err.userInfo["NSHTTPStatusCode"] as? Int { return code }
            current = err.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }
}
