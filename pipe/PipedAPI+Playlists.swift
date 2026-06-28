import Foundation

/// Playlist endpoints, split out of PipedAPI to keep each file single-purpose.
extension PipedAPI {
    static func playlistURL(_ id: String) -> URL {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return URL(string: "\(pipedBase)/playlists/\(encoded)")!
    }

    /// Fetch a playlist's contents (title, uploader, ordered videos).
    static func playlist(_ id: String) async throws -> PlaylistResponse {
        try await fetch(PlaylistResponse.self, from: playlistURL(id))
    }

    /// Fetch a channel "playlists" tab — its `content` is playlist references,
    /// not videos, so it decodes into PlaylistItems.
    static func playlistTab(_ tabData: String) async throws -> [PlaylistItem] {
        try await fetch(PlaylistTabResponse.self, from: channelTabURL(tabData)).content
    }
}

/// A page of a channel's playlists tab.
struct PlaylistTabResponse: Codable {
    let content: [PlaylistItem]
}
