import Foundation

/// Base URL of the Piped API instance. Mutable so Settings can repoint it.
var pipedBase = "https://pipedapi.jpc.io"

/// Preferred maximum cast resolution, mirrored from Settings so the pure
/// stream-selection helpers can read it without a dependency on AppSettings.
var pipedCastQuality: CastQuality = .auto

/// Decides whether a failed request should be retried and how long to wait.
/// Pure and synchronous so the policy is unit-testable without real delays.
enum RetryPolicy {
    static let maxAttempts = 3

    /// Gateway statuses the proxy in front of the instance answers while the
    /// instance restarts (e.g. its watchdog recreating it) — a short retry often
    /// lands. 4xx and 500 are the instance's own verdict and are not retried.
    static let transientStatuses: Set<Int> = [502, 503, 504]

    /// Whether an error is worth retrying (transient connectivity or gateway
    /// error, not a 4xx/decode).
    static func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        if let status = (error as? PipedError)?.statusCode { return transientStatuses.contains(status) }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    /// Backoff in nanoseconds before the given (1-based) attempt: 0, 0.4s, 0.8s…
    static func backoffNanos(beforeAttempt attempt: Int) -> UInt64 {
        guard attempt > 1 else { return 0 }
        return UInt64(attempt - 1) * 400_000_000
    }
}
