import Testing
import Foundation
@testable import pipe

/// Pure retry-policy tests — touch no global state, safe to run in parallel.
/// The integration tests that exercise retry through the live `PipedAPI.session`
/// live in `PipedAPITests` (the single serialized suite for session-mutating
/// tests): Swift Testing's `.serialized` only orders within one suite, so two
/// serialized suites touching the same global could still interleave.
struct RetryPolicyTests {

    // MARK: - shouldRetry

    @Test func retriesTransientNetworkErrors() {
        for code in [URLError.timedOut, .cannotConnectToHost, .networkConnectionLost,
                     .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost] {
            #expect(RetryPolicy.shouldRetry(URLError(code), attempt: 1) == true)
        }
    }

    @Test func doesNotRetryNonTransientErrors() {
        #expect(RetryPolicy.shouldRetry(URLError(.badURL), attempt: 1) == false)
        #expect(RetryPolicy.shouldRetry(URLError(.unsupportedURL), attempt: 1) == false)
    }

    @Test func doesNotRetryNonURLErrors() {
        struct Decoding: Error {}
        #expect(RetryPolicy.shouldRetry(Decoding(), attempt: 1) == false)
    }

    @Test func stopsAtMaxAttempts() {
        #expect(RetryPolicy.shouldRetry(URLError(.timedOut), attempt: RetryPolicy.maxAttempts) == false)
        #expect(RetryPolicy.shouldRetry(URLError(.timedOut), attempt: RetryPolicy.maxAttempts - 1) == true)
    }

    // MARK: - backoff

    @Test func backoffIsZeroForFirstAttemptThenGrows() {
        #expect(RetryPolicy.backoffNanos(beforeAttempt: 1) == 0)
        #expect(RetryPolicy.backoffNanos(beforeAttempt: 2) == 400_000_000)
        #expect(RetryPolicy.backoffNanos(beforeAttempt: 3) == 800_000_000)
    }
}
