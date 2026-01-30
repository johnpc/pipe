import Foundation

struct QueueItem: Identifiable, Equatable {
    let id = UUID()
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    let url: String
    let duration: Int
}

struct FollowedChannel: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let thumbnail: String
}
