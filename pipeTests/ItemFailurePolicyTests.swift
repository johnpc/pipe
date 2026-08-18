import Testing
import AVFoundation
@testable import pipe

struct ItemFailurePolicyTests {
    @Test func retriesWhileBudgetRemains() {
        #expect(ItemFailurePolicy.outcome(retries: 0, isLocal: false) == .retry)
        #expect(ItemFailurePolicy.outcome(retries: 1, isLocal: false) == .retry)
    }

    @Test func givesUpAtMaxRetries() {
        #expect(ItemFailurePolicy.outcome(retries: ItemFailurePolicy.maxRetries, isLocal: false) == .giveUp)
    }

    @Test func givesUpImmediatelyForLocalFiles() {
        // A downloaded file that fails is corrupt; re-resolving a remote URL
        // wouldn't address it, so don't burn retries pretending otherwise.
        #expect(ItemFailurePolicy.outcome(retries: 0, isLocal: true) == .giveUp)
    }

    @Test func failureMessageNamesTheItemAndReason() {
        let message = ItemFailurePolicy.failureMessage(title: "Liquid Death", reason: "no connection")
        #expect(message.contains("Liquid Death"))
        #expect(message.hasPrefix("Couldn't play"))
        #expect(message.hasSuffix("no connection"))
    }

    @Test func reasonSurfacesHTTPStatusFromUnderlyingError() {
        // AVFoundation buries the server status in an underlying error's userInfo.
        let underlying = NSError(domain: "CoreMediaErrorDomain", code: -12939,
                                 userInfo: ["NSHTTPStatusCode": 403])
        let top = NSError(domain: AVFoundationErrorDomain, code: -11800,
                          userInfo: [NSUnderlyingErrorKey: underlying])
        #expect(ItemFailurePolicy.reason(from: top).contains("403"))
    }

    @Test func reasonMapsCommonHTTPCodes() {
        for (code, needle) in [(404, "404"), (429, "429"), (500, "500")] {
            let err = NSError(domain: "x", code: 1, userInfo: ["NSHTTPStatusCode": code])
            #expect(ItemFailurePolicy.reason(from: err).contains(needle))
        }
    }

    @Test func reasonMapsURLErrors() {
        #expect(ItemFailurePolicy.reason(from: URLError(.notConnectedToInternet)) == "no connection")
        #expect(ItemFailurePolicy.reason(from: URLError(.timedOut)) == "the connection timed out")
    }

    @Test func reasonFallsBackWhenNoError() {
        #expect(ItemFailurePolicy.reason(from: nil) == "playback failed")
    }

    @Test func reasonUsesUnderlyingMessageForUnknownError() {
        let err = NSError(domain: "Some", code: 7, userInfo: [NSLocalizedDescriptionKey: "weird failure"])
        #expect(ItemFailurePolicy.reason(from: err) == "weird failure")
    }
}
