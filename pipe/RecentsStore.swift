import Foundation
import Combine

struct RecentItem: Codable, Identifiable, Equatable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    var timestamp: Double
    var lastWatched: Date
    var duration: Int
    var uploadedDate: String?
    
    init(videoId: String, title: String, artist: String, thumbnail: String, timestamp: Double, lastWatched: Date, duration: Int = 0, uploadedDate: String? = nil) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.thumbnail = thumbnail
        self.timestamp = timestamp
        self.lastWatched = lastWatched
        self.duration = duration
        self.uploadedDate = uploadedDate
    }
}

class RecentsStore: ObservableObject {
    @Published var items: [RecentItem] = []
    private let key = "recentItems"
    private let maxItems = 50
    
    init() { load() }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = decoded
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func add(videoId: String, title: String, artist: String, thumbnail: String, timestamp: Double, duration: Int = 0, uploadedDate: String? = nil) {
        items.removeAll { $0.videoId == videoId }
        let item = RecentItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, timestamp: timestamp, lastWatched: Date(), duration: duration, uploadedDate: uploadedDate)
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        save()
    }
    
    func updateTimestamp(videoId: String, timestamp: Double) {
        if let idx = items.firstIndex(where: { $0.videoId == videoId }) {
            items[idx].timestamp = timestamp
            items[idx].lastWatched = Date()
            save()
        }
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
