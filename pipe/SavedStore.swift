import Foundation
import Combine

/// A saved item ("Save for later") — minimal metadata to display and play.
struct SavedItem: Codable, Identifiable, Equatable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
}

/// Persisted "Save for later" list, mirroring the FollowingStore pattern with an
/// injectable UserDefaults so it's testable in isolation.
class SavedStore: ObservableObject {
    @Published var items: [SavedItem] = []
    private let key = "savedItems"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    nonisolated deinit {}

    func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SavedItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    func isSaved(_ videoId: String) -> Bool {
        items.contains { $0.videoId == videoId }
    }

    /// Save a video (no-op if already saved), newest at the front.
    func add(_ item: SavedItem) {
        guard !isSaved(item.videoId) else { return }
        items.insert(item, at: 0)
        save()
    }

    func remove(videoId: String) {
        items.removeAll { $0.videoId == videoId }
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where index < items.count {
            items.remove(at: index)
        }
        save()
    }

    /// Toggle saved state; returns the new state (true = now saved).
    @discardableResult
    func toggle(_ item: SavedItem) -> Bool {
        if isSaved(item.videoId) {
            remove(videoId: item.videoId)
            return false
        }
        add(item)
        return true
    }
}
