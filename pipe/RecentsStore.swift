import Foundation
import Combine

class RecentsStore: ObservableObject {
    @Published var items: [RecentItem] = []
    private let key = "recentItems"
    private let maxItems = 50
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // Opt the deinitializer out of MainActor isolation: there is no
    // actor-isolated cleanup here, and an isolated deinit triggers an
    // async executor hop that crashes under the current toolchain.
    nonisolated deinit {}

    func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
    
    /// Remove a single watched item by video id.
    func remove(videoId: String) {
        items.removeAll { $0.videoId == videoId }
        save()
    }

    /// Remove items at the given list offsets (for swipe-to-delete).
    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where index < items.count {
            items.remove(at: index)
        }
        save()
    }

    /// Clear the entire watch history.
    func clear() {
        items.removeAll()
        save()
    }

    func add(videoId: String, title: String, artist: String, thumbnail: String, timestamp: Double, duration: Int = 0, uploadedDate: String? = nil) {
        items.removeAll { $0.videoId == videoId }
        let item = RecentItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, timestamp: timestamp, lastWatched: Date(), duration: duration, uploadedDate: uploadedDate)
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        save()
    }
    
    /// Record the playback position. Called every second while playing, so
    /// it only writes (publish + persist) when the position moved by
    /// `RecentsPolicy.positionGranularity`, was reset to 0, or crossed the watched line;
    /// every write re-renders all history-aware rows and re-encodes the history.
    func updateTimestamp(videoId: String, timestamp: Double) {
        guard let idx = items.firstIndex(where: { $0.videoId == videoId }) else { return }
        guard RecentsPolicy.shouldRecordPosition(timestamp, over: items[idx]) else { return }
        var item = items[idx]  // one assignment = one publish, not one per field
        item.timestamp = timestamp
        item.lastWatched = Date()
        items[idx] = item
        save()
    }
    
    func getTimestamp(videoId: String) -> Double? {
        items.first { $0.videoId == videoId }?.timestamp
    }
    
    func getDuration(videoId: String) -> Int {
        items.first { $0.videoId == videoId }?.duration ?? 0
    }
    
    func hasPlayed(videoId: String) -> Bool {
        items.contains { $0.videoId == videoId }
    }
    
    func isCompleted(videoId: String) -> Bool {
        guard let item = items.first(where: { $0.videoId == videoId }),
              item.duration > 0 else { return false }
        return item.timestamp / Double(item.duration) >= 0.9
    }
    
    func resumeTime(videoId: String) -> Double? {
        guard let item = items.first(where: { $0.videoId == videoId }),
              item.duration > 0,
              item.timestamp / Double(item.duration) < 0.9,
              item.timestamp > 5 else { return nil }
        return item.timestamp
    }
}
