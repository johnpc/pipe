import Foundation

// Piped API response models, split out of PipedAPI.swift to keep files small.
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

struct ChannelResponse: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let description: String?
    let relatedStreams: [RelatedStream]
    let tabs: [ChannelTab]?
    let nextpage: String?
}

struct ChannelTab: Codable {
    let name: String
    let data: String
}

struct ChannelTabResponse: Codable {
    let content: [RelatedStream]
    let nextpage: String?
}

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

struct StreamResponse: Codable, Equatable {
    let title: String
    let description: String?
    let uploader: String
    let uploaderUrl: String?
    let duration: Int
    let hls: String?
    let audioStreams: [AudioStream]
    let videoStreams: [VideoStream]
    let thumbnailUrl: String
    let uploadDate: String?
    let chapters: [Chapter]?
}

/// A timeline marker within a video (YouTube chapters), as returned by Piped.
struct Chapter: Codable, Equatable, Identifiable {
    let title: String
    let start: Int      // seconds from the start of the video
    let image: String?

    var id: Int { start }
}

struct AudioStream: Codable, Equatable {
    let url: String
    let bitrate: Int
    let mimeType: String
}

struct VideoStream: Codable, Equatable {
    let url: String
    let quality: String
    let mimeType: String
    let videoOnly: Bool?
}
