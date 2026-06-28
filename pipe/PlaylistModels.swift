import Foundation

/// A playlist reference as it appears in a channel's "playlists" tab or in
/// search results. The `url` is "/playlist?list=<id>"; `videos` is the count.
struct PlaylistItem: Codable, Identifiable, Hashable {
    let url: String
    let name: String?
    let thumbnail: String?
    let uploaderName: String?
    let videos: Int?

    var id: String { url }
    var playlistId: String { PlaylistLogic.id(fromURL: url) }
    var displayName: String { name ?? "Playlist" }
    var displayThumbnail: String { thumbnail ?? "" }
    /// "12 videos", or nil when the count is unknown/≤0.
    var videoCountText: String? {
        guard let videos, videos > 0 else { return nil }
        return "\(videos) video\(videos == 1 ? "" : "s")"
    }
}

/// The contents of one playlist: its title, uploader, and ordered videos.
struct PlaylistResponse: Codable, Equatable {
    let name: String
    let thumbnailUrl: String?
    let uploader: String?
    let relatedStreams: [RelatedStream]
}
