import Foundation

/// A watched item with resume position and last-watched time, persisted by
/// `RecentsStore`.
struct RecentItem: Codable, Identifiable, Equatable, Hashable {
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
