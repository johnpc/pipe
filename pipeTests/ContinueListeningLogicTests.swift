import Testing
import Foundation
@testable import pipe

struct ContinueListeningLogicTests {
    private func item(_ id: String, timestamp: Double, duration: Int) -> RecentItem {
        RecentItem(videoId: id, title: id, artist: "a", thumbnail: "", timestamp: timestamp, lastWatched: Date(), duration: duration)
    }

    @Test func includesMidProgressItems() {
        let items = [item("a", timestamp: 50, duration: 100)]
        #expect(ContinueListeningLogic.inProgress(items).map(\.videoId) == ["a"])
    }

    @Test func excludesBarelyStarted() {
        let items = [item("a", timestamp: 3, duration: 100)]
        #expect(ContinueListeningLogic.inProgress(items).isEmpty)
    }

    @Test func excludesNearlyComplete() {
        let items = [item("a", timestamp: 95, duration: 100)]
        #expect(ContinueListeningLogic.inProgress(items).isEmpty)
    }

    @Test func excludesUnknownDuration() {
        let items = [item("a", timestamp: 50, duration: 0)]
        #expect(ContinueListeningLogic.inProgress(items).isEmpty)
    }

    @Test func preservesOrderAndCaps() {
        let items = (0..<15).map { item("v\($0)", timestamp: 50, duration: 100) }
        let result = ContinueListeningLogic.inProgress(items, limit: 10)
        #expect(result.count == 10)
        #expect(result.first?.videoId == "v0")
    }
}
