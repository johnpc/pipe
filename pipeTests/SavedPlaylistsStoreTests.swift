import Testing
import Foundation
@testable import pipe

@MainActor
struct SavedPlaylistsStoreTests {

    private func makeStore() -> SavedPlaylistsStore {
        SavedPlaylistsStore(defaults: UserDefaults(suiteName: "saved-pl-\(UUID().uuidString)")!)
    }

    private func sample(_ id: String = "PL1") -> SavedPlaylist {
        SavedPlaylist(playlistId: id, name: "Mix", thumbnail: "t", uploader: "U")
    }

    @Test func addThenIsSaved() {
        let store = makeStore()
        #expect(!store.isSaved("PL1"))
        store.add(sample())
        #expect(store.isSaved("PL1"))
        #expect(store.playlists.count == 1)
    }

    @Test func addIsIdempotent() {
        let store = makeStore()
        store.add(sample())
        store.add(sample())
        #expect(store.playlists.count == 1)
    }

    @Test func removeDeletes() {
        let store = makeStore()
        store.add(sample())
        store.remove(playlistId: "PL1")
        #expect(!store.isSaved("PL1"))
    }

    @Test func toggleFlipsState() {
        let store = makeStore()
        #expect(store.toggle(sample()) == true)
        #expect(store.isSaved("PL1"))
        #expect(store.toggle(sample()) == false)
        #expect(!store.isSaved("PL1"))
    }

    @Test func persistsAcrossInstances() {
        let suite = "saved-pl-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let first = SavedPlaylistsStore(defaults: defaults)
        first.add(sample("PLkeep"))
        let second = SavedPlaylistsStore(defaults: defaults)
        #expect(second.isSaved("PLkeep"))
    }

    @Test func newestSavedComesFirst() {
        let store = makeStore()
        store.add(sample("PLa"))
        store.add(sample("PLb"))
        #expect(store.playlists.first?.playlistId == "PLb")
    }
}
