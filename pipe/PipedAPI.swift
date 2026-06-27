import Foundation

/// Base URL of the Piped API instance. Mutable so Settings can point the app at
/// a different instance when the default is down. Defaults to jpc.io's instance.
var pipedBase = "https://pipedapi.jpc.io"

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

/// Decides whether a failed request should be retried and how long to wait.
/// Pure and synchronous so the policy is unit-testable without real delays.
enum RetryPolicy {
    static let maxAttempts = 3

    /// Whether an error is worth retrying (transient connectivity, not a 4xx/decode).
    static func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    /// Backoff in nanoseconds before the given (1-based) attempt: 0, 0.4s, 0.8s…
    static func backoffNanos(beforeAttempt attempt: Int) -> UInt64 {
        guard attempt > 1 else { return 0 }
        return UInt64(attempt - 1) * 400_000_000
    }
}

enum PipedAPI {
    /// Injectable session so tests can stub responses via a custom URLProtocol.
    /// Defaults to a session with a sensible request timeout.
    static var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Test seam for the inter-attempt delay so retry tests don't actually sleep.
    static var sleep: (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }

    /// Fetch + decode with bounded retry on transient network errors.
    static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, _) = try await session.data(from: url)
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                if RetryPolicy.shouldRetry(error, attempt: attempt) {
                    await sleep(RetryPolicy.backoffNanos(beforeAttempt: attempt + 1))
                    continue
                }
                throw error
            }
        }
    }

    /// Builds the search request URL. Pure, so URL construction is unit-testable.
    static func searchURL(_ query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "\(pipedBase)/search?q=\(encoded)&filter=all")!
    }

    static func channelTabURL(_ tabData: String) -> URL {
        let encoded = tabData.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tabData
        return URL(string: "\(pipedBase)/channels/tabs?data=\(encoded)")!
    }

    static func search(_ query: String) async throws -> [SearchItem] {
        try await fetch(SearchResponse.self, from: searchURL(query)).items
    }

    static func channel(_ id: String) async throws -> ChannelResponse {
        try await fetch(ChannelResponse.self, from: URL(string: "\(pipedBase)/channel/\(id)")!)
    }

    static func channelTab(_ tabData: String) async throws -> ChannelTabResponse {
        try await fetch(ChannelTabResponse.self, from: channelTabURL(tabData))
    }

    static func streams(_ videoId: String) async throws -> StreamResponse {
        try await fetch(StreamResponse.self, from: URL(string: "\(pipedBase)/streams/\(videoId)")!)
    }

    static func channelNextPageURL(channelId: String, nextpage: String) -> URL {
        let encoded = nextpage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nextpage
        return URL(string: "\(pipedBase)/nextpage/channel/\(channelId)?nextpage=\(encoded)")!
    }

    /// Fetch the next page of a channel's videos. Returns the page's streams and
    /// the following page token (nil when exhausted).
    static func channelNextPage(channelId: String, nextpage: String) async throws -> ChannelTabResponse {
        try await fetch(ChannelTabResponse.self, from: channelNextPageURL(channelId: channelId, nextpage: nextpage))
    }
}
