import Foundation

/// Stream resolution and caption fetching, split from the PipedAPI core.
extension PipedAPI {
    /// Resolve a video's streams, serving a still-fresh cached response when one
    /// exists (see `StreamCache`) — the extractor round-trip is the slow part of
    /// "Loading...", so repeat plays of a recently-resolved video start
    /// instantly. Recovery paths that exist to mint a NEW URL (dead-on-arrival
    /// stream, premature end) pass `bypassingCache: true` — re-serving the
    /// cached URL there would just fail identically.
    static func streams(_ videoId: String, bypassingCache: Bool = false) async throws -> StreamResponse {
        if !bypassingCache, let cached = StreamCache.get(videoId) { return cached }
        let response = try await fetch(StreamResponse.self, from: URL(string: "\(pipedBase)/streams/\(videoId)")!)
        StreamCache.put(videoId, response)
        return response
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
}
