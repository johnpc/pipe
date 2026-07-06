import Foundation

extension Playback {
    /// Human-readable reason for a stream fetch failure, so a failed add/play can
    /// tell the user *why* instead of a generic "try again" — and so the same
    /// reason lands in the diagnostic log for later root-causing.
    static func errorReason(_ error: Error) -> String {
        // The instance told us why it failed (throttled/broken upstream) — use
        // its own message rather than a generic guess.
        if let pipedError = error as? PipedError { return pipedError.message }
        guard let urlError = error as? URLError else {
            // Any other non-URL error here is a genuine decode failure: the reply
            // wasn't a playable stream and wasn't a recognizable Piped error body.
            return "video unavailable"
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "no connection"
        case .timedOut:
            return "timed out"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "can't reach the Piped instance"
        default:
            return "network error"
        }
    }

    /// Toast copy for a failed action, naming the cause (e.g. "Couldn't add — no
    /// connection"). Pure so tests can assert it.
    static func errorMessage(for action: Action, error: Error) -> String {
        let verb = action == .play ? "Couldn't play" : "Couldn't add"
        return "\(verb) — \(errorReason(error))"
    }

    /// Diagnostic event name for a failed action, so queue-add failures are
    /// distinguishable from play failures in the exported/uploaded log.
    static func errorEventName(for action: Action) -> String {
        action == .play ? "playFailed" : "queueAddFailed"
    }
}
