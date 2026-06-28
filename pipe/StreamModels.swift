import Foundation

/// Full metadata for a single video: streams, chapters, related videos.
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
    let relatedStreams: [RelatedStream]?
}

/// A YouTube chapter timeline marker, as returned by Piped.
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
