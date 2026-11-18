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

    /// Fetch + decode from the configured instance, moving on to the fallback
    /// instance (when one is set) if the first one is unreachable. The instances
    /// and route holder are read once, up front (defaults: the live settings and
    /// the app-wide router), so a request never mixes two configurations and
    /// tests can drive it without touching process-wide state.
    static func fetch<T: Decodable>(_ type: T.Type, from url: URL,
                                    primary: String = pipedBase, fallback: String = pipedFallbackBase,
                                    router: InstanceRouter = .shared,
                                    now: () -> Date = { Date() }) async throws -> T {
        // No server configured: say so instead of letting a relative URL fail
        // with an opaque network error (the Feed/Search tabs show setup instead).
        guard !primary.isEmpty else { throw PipedError.noInstance }
        let candidates = InstanceFailover.candidates(for: url, primary: primary, fallback: fallback,
                                                     route: router.route, now: now())
        var lastError: Error = URLError(.unknown)
        for candidate in candidates {
            do {
                let value = try await fetchRetrying(type, from: candidate.url)
                router.route = InstanceFailover.route(afterSuccessOn: candidate.base, primary: primary, now: now())
                return value
            } catch {
                lastError = PipedError.translated(error)
                guard InstanceFailover.shouldTryNext(after: error) else { throw lastError }
            }
        }
        throw lastError
    }

    /// Fetch + decode one URL with bounded retry on transient network errors.
    private static func fetchRetrying<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    // Never try to decode an error page: a 502 from the proxy in
                    // front of a dead instance used to decode-fail into a
                    // misleading "video unavailable". Prefer Piped's own envelope.
                    throw PipedErrorEnvelope.error(from: data) ?? PipedError.http(http.statusCode)
                }
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
