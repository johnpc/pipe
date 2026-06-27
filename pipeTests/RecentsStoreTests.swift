import Testing
import Foundation
@testable import pipe

@MainActor
struct RecentsStoreTests {

    /// Fresh, isolated UserDefaults suite per test so state never leaks.
    private func makeStore() -> RecentsStore {
        let suite = UserDefaults(suiteName: "test-recents-\(UUID().uuidString)")!
        return RecentsStore(defaults: suite)
    }

    @Test func addInsertsAtFront() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 0)
        store.add(videoId: "b", title: "B", artist: "x", thumbnail: "", timestamp: 0)
        #expect(store.items.first?.videoId == "b")
        #expect(store.items.count == 2)
    }

    @Test func addDeduplicatesByVideoId() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 0)
        store.add(videoId: "a", title: "A2", artist: "x", thumbnail: "", timestamp: 0)
        #expect(store.items.count == 1)
        #expect(store.items.first?.title == "A2")
    }

    @Test func capsAtFiftyItems() {
        let store = makeStore()
        for i in 0..<60 { store.add(videoId: "v\(i)", title: "t", artist: "x", thumbnail: "", timestamp: 0) }
        #expect(store.items.count == 50)
        #expect(store.items.first?.videoId == "v59")
    }

    @Test func updateTimestampUpdatesExisting() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 0, duration: 100)
        store.updateTimestamp(videoId: "a", timestamp: 30)
        #expect(store.getTimestamp(videoId: "a") == 30)
    }

    @Test func updateTimestampNoOpForMissing() {
        let store = makeStore()
        store.updateTimestamp(videoId: "missing", timestamp: 30)
        #expect(store.getTimestamp(videoId: "missing") == nil)
    }

    @Test func getDurationAndHasPlayed() {
        let store = makeStore()
        #expect(store.hasPlayed(videoId: "a") == false)
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 0, duration: 250)
        #expect(store.hasPlayed(videoId: "a") == true)
        #expect(store.getDuration(videoId: "a") == 250)
        #expect(store.getDuration(videoId: "missing") == 0)
    }

    @Test func isCompletedWhenPastNinetyPercent() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 95, duration: 100)
        #expect(store.isCompleted(videoId: "a") == true)
    }

    @Test func isNotCompletedEarlyOrUnknownDuration() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 10, duration: 100)
        store.add(videoId: "b", title: "B", artist: "x", thumbnail: "", timestamp: 10, duration: 0)
        #expect(store.isCompleted(videoId: "a") == false)
        #expect(store.isCompleted(videoId: "b") == false)
        #expect(store.isCompleted(videoId: "missing") == false)
    }

    @Test func resumeTimeReturnsMidPlaybackPosition() {
        let store = makeStore()
        store.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 40, duration: 100)
        #expect(store.resumeTime(videoId: "a") == 40)
    }

    @Test func resumeTimeNilWhenTooEarlyOrComplete() {
        let store = makeStore()
        store.add(videoId: "early", title: "", artist: "", thumbnail: "", timestamp: 3, duration: 100)
        store.add(videoId: "done", title: "", artist: "", thumbnail: "", timestamp: 95, duration: 100)
        #expect(store.resumeTime(videoId: "early") == nil)
        #expect(store.resumeTime(videoId: "done") == nil)
        #expect(store.resumeTime(videoId: "missing") == nil)
    }

    @Test func persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "test-recents-persist-\(UUID().uuidString)")!
        let store1 = RecentsStore(defaults: suite)
        store1.add(videoId: "a", title: "A", artist: "x", thumbnail: "", timestamp: 5, duration: 10)
        let store2 = RecentsStore(defaults: suite)
        #expect(store2.items.count == 1)
        #expect(store2.items.first?.videoId == "a")
    }
}
