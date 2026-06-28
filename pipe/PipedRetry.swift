import Foundation

/// Base URL of the Piped API instance. Mutable so Settings can repoint it.
var pipedBase = "https://pipedapi.jpc.io"

/// Decides whether a failed request should be retried and how long to wait.
/// Pure and synchronous so the policy is unit-testable without real delays.
enum RetryPolicy {
    static let maxAttempts = 3

    /// Whether an error is worth retrying (transient connectivity, not a 4xx/decode).
    static func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
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
