import Testing
import Foundation
@testable import pipe

struct NextItemPrefetchPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ id: String, resolvedAt: Date?) -> QueueItem {
        QueueItem(videoId: id, title: id, artist: "", thumbnail: "", url: "u", audioUrl: "", duration: 100, uploadedDate: nil, resolvedAt: resolvedAt)
    }

    private func candidate(_ queue: [QueueItem], index: Int = 0, time: Double = 950, duration: Double = 1000,
                           inFlight: String? = nil, local: Set<String> = []) -> String? {
        NextItemPrefetchPolicy.candidate(queue: queue, currentIndex: index, currentTime: time, duration: duration,
                                         now: now, inFlight: inFlight, isLocal: { local.contains($0) })?.videoId
    }

    @Test func staleNextItemNearTheEndIsDue() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: nil)]
        #expect(candidate(q) == "b")
    }

    @Test func notDueUntilWithinLeadTime() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: nil)]
        #expect(candidate(q, time: 1000 - NextItemPrefetchPolicy.leadTime - 1) == nil)
        #expect(candidate(q, time: 1000 - NextItemPrefetchPolicy.leadTime) == "b")
    }

    @Test func freshNextItemIsNotRefetched() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: now)]
        #expect(candidate(q) == nil)
    }

    @Test func urlThatExpiresBeforeItPlaysCountsAsStale() {
        // Resolved just under the max age ago: fresh now, stale 50s from now
        // when the current item ends.
        let resolved = now.addingTimeInterval(-StreamFreshness.maxAge + 10)
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: resolved)]
        #expect(candidate(q) == "b")
    }

    @Test func nothingToPrefetchAtTheEndOfTheQueue() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: nil)]
        #expect(candidate(q, index: 1) == nil)
        #expect(candidate(q, index: -1) == nil)
    }

    @Test func unknownDurationNeverPrefetches() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: nil)]
        #expect(candidate(q, duration: 0) == nil)
    }

    @Test func inFlightAndLocalItemsAreSkipped() {
        let q = [item("a", resolvedAt: now), item("b", resolvedAt: nil)]
        #expect(candidate(q, inFlight: "b") == nil)
        #expect(candidate(q, local: ["b"]) == nil)
    }
}
