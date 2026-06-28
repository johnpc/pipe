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

    var id: String { url }
    var isChannel: Bool { type == "channel" }
    var videoId: String { url.replacingOccurrences(of: "/watch?v=", with: "") }
    var channelId: String { url.replacingOccurrences(of: "/channel/", with: "") }
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
