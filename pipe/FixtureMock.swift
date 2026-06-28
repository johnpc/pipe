import Foundation

/// Maps a Piped API request path to a bundled fixture file name.
/// Pure and synchronous so the routing is unit-testable without the network.
enum FixtureRouter {
    static func fixtureName(for url: URL) -> String? {
        let path = url.path
        if path.hasPrefix("/search") { return "search" }
        if path.hasPrefix("/channels/tabs") { return "channelTab" }
        if path.hasPrefix("/channel/") { return "channel" }
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

    override func startLoading() {
        if FixtureURLProtocol.failStreams, request.url?.path.hasPrefix("/streams/") == true {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        guard let url = request.url,
              let name = FixtureRouter.fixtureName(for: url),
              let data = FixtureURLProtocol.loader(name) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Wires the app to serve bundled fixtures when launched for UI testing.
enum MockMode {
    static let launchArgument = "--uitest-mock"

    /// True when the process was launched in UI-test mock mode.
    static func isEnabled(_ args: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        args.contains(launchArgument)
    }

    /// Point PipedAPI at a fixture-backed session.
    static func activate() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        PipedAPI.session = URLSession(configuration: config)
    }

    static let failArgument = "--uitest-fail-streams"

    /// Activate only when the launch argument is present. Also honors a flag that
    /// makes `/streams/` requests error, for the error-recovery UI test.
    static func activateIfNeeded(_ args: [String] = ProcessInfo.processInfo.arguments) {
        guard isEnabled(args) else { return }
        FixtureURLProtocol.failStreams = args.contains(failArgument)
        activate()
    }
}
