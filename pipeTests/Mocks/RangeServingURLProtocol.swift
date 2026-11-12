import Foundation

/// Serves one canned body to every request and records the `Range` headers it
/// saw. Dedicated to the segment-index tests (not the shared `MockURLProtocol`)
/// so they can't race other suites over a static handler.
final class RangeServingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var body = Data()
    /// When set, the first request gets only this many bytes of `body`.
    nonisolated(unsafe) static var cutFirst: Int?
    nonisolated(unsafe) static var status = 206
    nonisolated(unsafe) private(set) static var ranges: [String] = []

    static func makeSession(serving data: Data, cutFirst: Int? = nil, status: Int = 206) -> URLSession {
        body = data
        self.cutFirst = cutFirst
        self.status = status
        ranges = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RangeServingURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.ranges.append(request.value(forHTTPHeaderField: "Range") ?? "")
        let data = Self.ranges.count == 1 ? Self.body.prefix(Self.cutFirst ?? Self.body.count) : Self.body
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
