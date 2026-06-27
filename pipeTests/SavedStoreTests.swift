import Testing
import Foundation
@testable import pipe

@MainActor
struct SavedStoreTests {

    private func makeStore() -> SavedStore {
        SavedStore(defaults: UserDefaults(suiteName: "saved-\(UUID().uuidString)")!)
    }

    private func item(_ id: String) -> SavedItem {
        SavedItem(videoId: id, title: "T-\(id)", artist: "A", thumbnail: "t", duration: 10)
    }

    @Test func addInsertsAtFront() {
        let store = makeStore()
        store.add(item("a"))
        store.add(item("b"))
        #expect(store.items.map(\.videoId) == ["b", "a"])
    }

    @Test func addIsIdempotent() {
        let store = makeStore()
        store.add(item("a"))
        store.add(item("a"))
        #expect(store.items.count == 1)
    }

    @Test func isSavedReflectsState() {
        let store = makeStore()
        #expect(store.isSaved("a") == false)
        store.add(item("a"))
        #expect(store.isSaved("a") == true)
    }

    @Test func removeDeletes() {
        let store = makeStore()
        store.add(item("a"))
        store.add(item("b"))
        store.remove(videoId: "a")
        #expect(store.items.map(\.videoId) == ["b"])
    }

    @Test func removeAtOffsets() {
        let store = makeStore()
        store.add(item("a")); store.add(item("b")); store.add(item("c")) // [c,b,a]
        store.remove(at: IndexSet([0, 2]))
        #expect(store.items.map(\.videoId) == ["b"])
    }

    @Test func toggleAddsThenRemoves() {
        let store = makeStore()
        let nowSaved = store.toggle(item("a"))
        #expect(nowSaved == true)
        #expect(store.isSaved("a"))
        let nowUnsaved = store.toggle(item("a"))
        #expect(nowUnsaved == false)
        #expect(store.isSaved("a") == false)
    }

    @Test func persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "saved-persist-\(UUID().uuidString)")!
        SavedStore(defaults: suite).add(item("x"))
        #expect(SavedStore(defaults: suite).items.map(\.videoId) == ["x"])
    }

    @Test func savedItemRoundTrips() throws {
        let i = item("a")
        let data = try JSONEncoder().encode(i)
        let decoded = try JSONDecoder().decode(SavedItem.self, from: data)
        #expect(decoded == i)
        #expect(decoded.id == "a")
    }
}
