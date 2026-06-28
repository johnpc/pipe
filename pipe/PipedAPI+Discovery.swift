import Foundation

/// Discovery endpoints: trending + comments.
extension PipedAPI {

    static func trendingURL(region: String) -> URL {
        URL(string: "\(pipedBase)/trending?region=\(region)")!
    }

    /// Trending videos for a region (default US). Items share the RelatedStream shape.
    static func trending(region: String = "US") async throws -> [RelatedStream] {
        try await fetch([RelatedStream].self, from: trendingURL(region: region))
    }

    /// Top-level comments for a video.
    static func comments(_ videoId: String) async throws -> CommentsResponse {
        try await fetch(CommentsResponse.self, from: URL(string: "\(pipedBase)/comments/\(videoId)")!)
    }
}
