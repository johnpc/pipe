import Foundation

enum PipedAPI {
    /// Injectable session so tests can stub responses via a custom URLProtocol.
    /// Defaults to a session with a sensible request timeout. Tests mutate this;
    /// the test target runs non-parallel (see pipe.xctestplan) so the shared
    /// mutation can't race across suites.
    nonisolated(unsafe) static var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Test seam for the inter-attempt delay so retry tests don't actually sleep.
    nonisolated(unsafe) static var sleep: (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }

    /// Fetch + decode with bounded retry on transient network errors.
    static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, _) = try await session.data(from: url)
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch let decodeError {
                    // Piped answers 200 with an {error,message} body when it can't
                    // extract a video; report its real message, not "data missing".
                    if let pipedError = PipedErrorEnvelope.error(from: data) { throw pipedError }
                    throw decodeError
                }
            } catch {
                if RetryPolicy.shouldRetry(error, attempt: attempt) {
                    await sleep(RetryPolicy.backoffNanos(beforeAttempt: attempt + 1))
                    continue
                }
                throw error
            }
        }
    }

    /// Fetch a raw text document (e.g. a TTML subtitle track) from an absolute
    /// URL. Retries transient network errors like `fetch`, but skips JSON
    /// decoding since captions are XML/text.
    static func rawText(from url: URL) async throws -> String {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, _) = try await session.data(from: url)
                return String(decoding: data, as: UTF8.self)
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
