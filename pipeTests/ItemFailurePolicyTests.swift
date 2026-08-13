import Testing
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

    @Test func failureMessageNamesTheItem() {
        let message = ItemFailurePolicy.failureMessage(title: "Liquid Death")
        #expect(message.contains("Liquid Death"))
        #expect(message.hasPrefix("Couldn't play"))
    }
}
