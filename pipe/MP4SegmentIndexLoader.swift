import Foundation

/// Fetches just the head of a fragmented MP4 over HTTP and decodes its segment
/// index. A `Range` request keeps this to a few hundred KB; if the `sidx` box
/// turns out to extend past that, the fetch grows to cover it (bounded).
enum MP4SegmentIndexLoader {
    /// First fetch: ample for YouTube's `moov` + a multi-hour `sidx`.
    static let initialBytes = 256 * 1024
    /// Give up rather than download megabytes looking for an index.
    static let maxBytes = 4 * 1024 * 1024

    static func load(_ url: URL, session: URLSession = .shared) async throws -> MP4SegmentIndex {
        var data = try await fetch(url, upTo: initialBytes, session: session)
        while true {
            do {
                return try MP4SegmentIndex.parse(data)
            } catch MP4SegmentIndex.Failure.truncated(let needed) where needed <= maxBytes {
                let more = try await fetch(url, upTo: needed, session: session)
                // A server that ignores Range already sent everything it has.
                guard more.count > data.count else { throw MP4SegmentIndex.Failure.noIndex }
                data = more
            }
        }
    }

    static func fetch(_ url: URL, upTo length: Int, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(length - 1)", forHTTPHeaderField: "Range")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
