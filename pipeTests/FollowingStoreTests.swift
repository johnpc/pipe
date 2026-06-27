import Testing
import Foundation
@testable import pipe

@MainActor
struct FollowingStoreTests {

    private func makeStore() -> FollowingStore {
        let suite = UserDefaults(suiteName: "test-following-\(UUID().uuidString)")!
        return FollowingStore(defaults: suite)
    }

    private func channel(_ id: String) -> FollowedChannel {
        FollowedChannel(id: id, name: "Chan \(id)", thumbnail: "t")
    }

    @Test func followAddsChannel() {
        let store = makeStore()
        store.follow(channel("c1"))
        #expect(store.channels.count == 1)
        #expect(store.isFollowing("c1"))
    }

    @Test func followIsIdempotent() {
        let store = makeStore()
        store.follow(channel("c1"))
        store.follow(channel("c1"))
        #expect(store.channels.count == 1)
    }

    @Test func unfollowRemovesChannel() {
        let store = makeStore()
        store.follow(channel("c1"))
        store.follow(channel("c2"))
        store.unfollow("c1")
        #expect(store.channels.count == 1)
        #expect(store.isFollowing("c1") == false)
        #expect(store.isFollowing("c2") == true)
    }

    @Test func isFollowingFalseForUnknown() {
        let store = makeStore()
        #expect(store.isFollowing("nope") == false)
    }

    @Test func persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "test-following-persist-\(UUID().uuidString)")!
        let store1 = FollowingStore(defaults: suite)
        store1.follow(FollowedChannel(id: "c1", name: "C", thumbnail: "t"))
        let store2 = FollowingStore(defaults: suite)
        #expect(store2.isFollowing("c1"))
    }
}
