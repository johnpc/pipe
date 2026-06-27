import Foundation

struct QueueItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    /// Full A/V video stream URL.
    let url: String
    /// Audio-only stream URL (empty when the source had no audio-only track).
    let audioUrl: String
    let duration: Int
    let uploadedDate: String?

    // `id` is generated, not part of the persisted payload.
    enum CodingKeys: String, CodingKey {
        case videoId, title, artist, thumbnail, url, audioUrl, duration, uploadedDate
    }

    /// URL to play for the given mode: audio-only when available and not in
    /// video mode; otherwise the full video stream.
    func playbackURL(videoMode: Bool) -> String {
        (!videoMode && !audioUrl.isEmpty) ? audioUrl : url
    }
}

struct FollowedChannel: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let thumbnail: String
}
