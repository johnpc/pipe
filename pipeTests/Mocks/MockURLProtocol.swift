import Foundation

/// URLProtocol stub that lets tests return canned responses for any request,
/// so PipedAPI decoding can be exercised without hitting the network.
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Convenience: install a session backed by this protocol and point PipedAPI at it.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Stub the next response with a JSON string and reset PipedAPI's session.
    static func stub(json: String, status: Int = 200) {
        requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }

    static func stubError(_ error: Error) {
        requestHandler = { _ in throw error }
    }

    /// Number of requests served since the last reset — lets retry tests assert
    /// how many attempts were made.
    static private(set) var requestCount = 0

    /// Fail with `error` for the first `times` requests, then return `json`.
    /// Exercises the retry path deterministically.
    static func failThenSucceed(times: Int, error: Error, json: String) {
        requestCount = 0
        requestHandler = { request in
            requestCount += 1
            if requestCount <= times { throw error }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }

    static func resetCount() { requestCount = 0 }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
