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
/// backend, no flakiness, no skips. Activated only via `MockMode`.
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

    /// When true, only `/streams/` requests fail — so search still returns
    /// results but opening a video detail fails, exercising the Retry UI.
    static var failStreams = false

    /// When true, `/streams/` requests return a Piped error envelope (HTTP 200
    /// with `{error,message}`), exercising the real-message error toast.
    static var errorStreams = false

    /// When true, `/streams/` requests answer like the proxy in front of a dead
    /// instance does — HTTP 502 with an HTML body — the actual failure mode of
    /// an instance outage, exercising the status-naming error toast.
    static var downStreams = false

    /// Body the 502 mode serves: what nginx returns when its upstream is gone.
    static let downBody = Data("<html><body><h1>502 Bad Gateway</h1></body></html>".utf8)

    override func startLoading() {
        guard let url = request.url else { return }
        if url.path.hasPrefix("/streams/") {
            if FixtureURLProtocol.failStreams {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            if FixtureURLProtocol.errorStreams {
                let body = Data(#"{"error":"ParsingException","message":"JSON response is too short"}"#.utf8)
                return respond(url: url, status: 200, body: body, contentType: "application/json")
            }
            if FixtureURLProtocol.downStreams {
                return respond(url: url, status: 502, body: FixtureURLProtocol.downBody, contentType: "text/html")
            }
        }
        guard let name = FixtureRouter.fixtureName(for: url),
              let data = FixtureURLProtocol.loader(name) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        respond(url: url, status: 200, body: data, contentType: "application/json")
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
