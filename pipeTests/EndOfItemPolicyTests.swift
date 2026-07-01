import Testing
@testable import pipe

struct EndOfItemPolicyTests {
    @Test func finishedWhenNoExpectedDuration() {
        #expect(EndOfItemPolicy.outcome(reached: 0, expected: nil, retries: 0) == .finished)
        #expect(EndOfItemPolicy.outcome(reached: 5, expected: 0, retries: 0) == .finished)
    }

    @Test func finishedWhenNearExpectedEnd() {
        // Played to (or nearly to) the reported duration → genuine finish.
        #expect(EndOfItemPolicy.outcome(reached: 3600, expected: 3600, retries: 0) == .finished)
        #expect(EndOfItemPolicy.outcome(reached: 3580, expected: 3600, retries: 0) == .finished)
    }

    @Test func recoverWhenEndsFarTooEarly() {
        // The "1-hour video ends at 30 min" case: recover instead of advancing.
        #expect(EndOfItemPolicy.outcome(reached: 1800, expected: 3600, retries: 0) == .recover)
    }

    @Test func giveUpAfterMaxRetries() {
        #expect(EndOfItemPolicy.outcome(reached: 1800, expected: 3600, retries: EndOfItemPolicy.maxRetries) == .giveUp)
    }

    @Test func shortClipNearEndIsFinishedNotPremature() {
        // A 6s clip ending at 3s: within the absolute floor, treat as finished so
        // tiny items aren't misread as truncated.
        #expect(EndOfItemPolicy.outcome(reached: 3, expected: 6, retries: 0) == .finished)
    }
}
