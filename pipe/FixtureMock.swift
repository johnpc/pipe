import Foundation

/// Maps a Piped API request path to a bundled fixture file name.
/// Pure and synchronous so the routing is unit-testable without the network.
enum FixtureRouter {
    static func fixtureName(for url: URL) -> String? {
        let path = url.path
        if path.hasPrefix("/search") { return "search" }
        if path.hasPrefix("/channels/tabs") {
            // The same endpoint serves video tabs and playlist tabs; the opaque
            // `data` token tells them apart in mock mode.
            let data = url.query ?? ""
            return data.contains("playlist") ? "channelPlaylistTab" : "channelTab"
        }
        if path.hasPrefix("/channel/") { return "channel" }
        if path.hasPrefix("/playlists/") { return "playlist" }
        if path.hasPrefix("/streams/") { return "streams" }
        if path.hasPrefix("/trending") { return "trending" }
        if path.hasPrefix("/comments/") { return "comments" }
        return nil
    }
}

/// URLProtocol that answers Piped API requests from bundled JSON fixtures, so
/// the app can run against deterministic real-shaped data in UI tests — no live
/// backend, no flakiness, no skips. `/streams/<id>` answers with that video's
/// own title (see `FixtureCatalog`), so a scenario can assert that the video it
/// tapped is the one that plays. Activated only via `MockMode`.
final class FixtureURLProtocol: URLProtocol {
    /// Test seam: overridable loader so the routing can be unit-tested without
    /// reading from the app bundle.
    static var loader: (String) -> Data? = { name in
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.main.url(forResource: name, withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return FixtureRouter.fixtureName(for: url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// How `/streams/` requests are answered (everything else always serves its
    /// fixture). One value, since the modes are mutually exclusive.
    static var streamMode: StreamMode = .normal

    enum StreamMode: Equatable {
        /// The (personalized) streams fixture.
        case normal
        /// A network error — search still works but a video fails to open,
        /// exercising the Retry UI.
        case networkFailure
        /// A Piped error envelope (HTTP 200 with `{error,message}`), exercising
        /// the real-message error toast.
        case pipedError
        /// What the proxy in front of a dead instance returns — HTTP 502 with
        /// an HTML body — exercising the status-naming error toast.
        case instanceDown

        /// The mode a UI-test launch asked for (first matching flag wins).
        static func from(arguments args: [String]) -> StreamMode {
            if args.contains(MockMode.failArgument) { return .networkFailure }
            if args.contains(MockMode.errorArgument) { return .pipedError }
            if args.contains(MockMode.downArgument) { return .instanceDown }
            return .normal
        }
    }

    override func startLoading() {
        guard let url = request.url else { return }
        if url.path.hasPrefix("/streams/") {
            if FixtureURLProtocol.streamMode == .networkFailure {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            if let canned = FixtureURLProtocol.cannedStreams(for: url) {
                return respond(url: url, status: canned.status, body: canned.body, contentType: canned.contentType)
            }
        }
        guard let name = FixtureRouter.fixtureName(for: url),
              let data = FixtureURLProtocol.loader(name) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        respond(url: url, status: 200, body: FixtureURLProtocol.personalized(data, for: url), contentType: "application/json")
    }

    struct Canned: Equatable {
        let status: Int
        let body: Data
        let contentType: String
    }

    /// Body the 502 mode serves: what nginx returns when its upstream is gone.
    static let downBody = Data("<html><body><h1>502 Bad Gateway</h1></body></html>".utf8)
    /// A Piped error envelope on HTTP 200 (the extractor hiccup shape).
    static let pipedErrorBody = Data(#"{"error":"ParsingException","message":"JSON response is too short"}"#.utf8)
    /// What Piped answers for a premiere that has not started (HTTP 500 with
    /// its error envelope), for catalog videos listed with a negative duration.
    static let premiereBody = Data(#"{"error":"ContentNotAvailableException","message":"This live event will begin in 6 hours."}"#.utf8)

    /// The `/streams/` answers that are not the fixture: the error modes, or
    /// Piped's premiere envelope for an unaired catalog video. Nil = serve the
    /// (personalized) fixture. Pure, so every branch is unit-tested.
    static func cannedStreams(for url: URL) -> Canned? {
        switch streamMode {
        case .pipedError: return Canned(status: 200, body: pipedErrorBody, contentType: "application/json")
        case .instanceDown: return Canned(status: 502, body: downBody, contentType: "text/html")
        case .normal, .networkFailure:
            return premiereEnvelope(for: url).map { Canned(status: 500, body: $0, contentType: "application/json") }
        }
    }

    static func premiereEnvelope(for url: URL) -> Data? {
        guard let id = FixtureCatalog.videoId(fromStreamsPath: url.path),
              let video = FixtureCatalog.video(id, loader: loader), video.duration < 0 else { return nil }
        return premiereBody
    }

    /// The streams template rewritten for the requested id when the catalog
    /// knows it; other requests (and unknown ids) pass through unchanged.
    static func personalized(_ data: Data, for url: URL) -> Data {
        guard let id = FixtureCatalog.videoId(fromStreamsPath: url.path),
              let video = FixtureCatalog.video(id, loader: loader) else { return data }
        return FixtureCatalog.personalize(data, for: video)
    }

    private func respond(url: URL, status: Int, body: Data, contentType: String) {
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                             headerFields: ["Content-Type": contentType]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
