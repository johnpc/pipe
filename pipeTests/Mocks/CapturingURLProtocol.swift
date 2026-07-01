import Foundation

/// A dedicated capturing URLProtocol for the diagnostics remote-sink tests.
///
/// Kept separate from `MockURLProtocol` so these tests don't race the PipedAPI
/// tests over a shared static handler when suites run in parallel. The captured
/// request/body live in a thread-safe box the test owns.
final class CapturingURLProtocol: URLProtocol {
    /// Set by each test before exercising the sink; guarded by `lock`.
    nonisolated(unsafe) static var onRequest: ((URLRequest) -> Void)?
    private static let lock = NSLock()

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func setHandler(_ handler: @escaping (URLRequest) -> Void) {
        lock.lock(); defer { lock.unlock() }
        onRequest = handler
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        CapturingURLProtocol.lock.lock()
        let handler = CapturingURLProtocol.onRequest
        CapturingURLProtocol.lock.unlock()
        handler?(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"ok\":true}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
