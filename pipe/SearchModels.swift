import Foundation

/// A search result row — a video or a channel (`type` distinguishes them).
struct SearchItem: Codable, Identifiable, Hashable {
    let url: String
    let type: String
    let title: String?
    let thumbnail: String?
    let uploaderName: String?
    let uploaderUrl: String?
    let duration: Int?
    let name: String?
    let uploadedDate: String?
    let verified: Bool?
    let subscribers: Int?
    let videos: Int?

    var id: String { url }
    var isChannel: Bool { type == "channel" }
    var isPlaylist: Bool { type == "playlist" }
    var videoId: String { url.replacingOccurrences(of: "/watch?v=", with: "") }
    var channelId: String { url.replacingOccurrences(of: "/channel/", with: "") }
    var playlistId: String { PlaylistLogic.id(fromURL: url) }
    /// Project a playlist search result into a PlaylistItem for PlaylistRow.
    var asPlaylistItem: PlaylistItem {
        PlaylistItem(url: url, name: name ?? title, thumbnail: thumbnail, uploaderName: uploaderName, videos: videos)
    }
    var displayTitle: String { name ?? title ?? "Unknown" }
    var displayUploader: String { uploaderName ?? "" }
    var displayThumbnail: String { thumbnail ?? "" }
    var isVerified: Bool { verified ?? false }
    /// Human-readable subscriber count (e.g. "505M"), or nil when unknown/≤0.
    var subscriberText: String? { ChannelFormat.subscribers(subscribers) }
}

struct SearchResponse: Codable {
    let items: [SearchItem]
}
