import Foundation
import Combine

/// A saved playlist — minimal metadata to list and reopen it later.
struct SavedPlaylist: Codable, Identifiable, Hashable {
    var id: String { playlistId }
    let playlistId: String
    let name: String
    let thumbnail: String
    let uploader: String
}

/// Persisted list of saved playlists, mirroring SavedStore with an injectable
/// UserDefaults so it's testable in isolation.
class SavedPlaylistsStore: ObservableObject {
    /// Shared instance for the views (mirrors ToastManager.shared). Tests
    /// construct their own with an injected UserDefaults for isolation.
    static let shared = SavedPlaylistsStore()

    @Published var playlists: [SavedPlaylist] = []
    private let key = "savedPlaylists"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    nonisolated deinit {}

    func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SavedPlaylist].self, from: data) {
            playlists = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: key)
        }
    }

    func isSaved(_ playlistId: String) -> Bool {
        playlists.contains { $0.playlistId == playlistId }
    }

    /// Save a playlist (no-op if already saved), newest at the front.
    func add(_ item: SavedPlaylist) {
        guard !isSaved(item.playlistId) else { return }
        playlists.insert(item, at: 0)
        save()
    }

    func remove(playlistId: String) {
        playlists.removeAll { $0.playlistId == playlistId }
        save()
    }

    /// Toggle saved state; returns the new state (true = now saved).
    @discardableResult
    func toggle(_ item: SavedPlaylist) -> Bool {
        if isSaved(item.playlistId) {
            remove(playlistId: item.playlistId)
            return false
        }
        add(item)
        return true
    }
}
