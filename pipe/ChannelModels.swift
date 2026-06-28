import Foundation

struct ChannelResponse: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let description: String?
    let relatedStreams: [RelatedStream]
    let tabs: [ChannelTab]?
    let nextpage: String?
}

/// A secondary tab on a channel (e.g. "shorts", "playlists"); `data` is an
/// opaque continuation token passed to the channels/tabs endpoint.
struct ChannelTab: Codable {
    let name: String
    let data: String
}

/// A page of a channel tab's content, with a next-page token.
struct ChannelTabResponse: Codable {
    let content: [RelatedStream]
    let nextpage: String?
}

/// A video reference as it appears in feeds, channels, related lists, trending.
struct RelatedStream: Codable, Identifiable, Hashable {
    let url: String
    let title: String
    let thumbnail: String
    let duration: Int
    let uploaderName: String?
    let uploadedDate: String?
    let uploaded: Int64?

    var id: String { url }
    var videoId: String { url.replacingOccurrences(of: "/watch?v=", with: "") }
}
