import Testing
import Foundation
@testable import pipe

/// Serialized: mutates the shared StreamCache (and, for the API-integration
/// test, the shared PipedAPI.session), so suites must not interleave.
@Suite(.serialized)
struct StreamCacheTests {

    private func makeStream(title: String = "t") -> StreamResponse {
        StreamResponse(title: title, description: nil, uploader: "u", uploaderUrl: nil, duration: 100, hls: nil, audioStreams: [], videoStreams: [], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
    }

    @Test func servesFreshEntry() {
        StreamCache.removeAll()
        let now = Date()
        StreamCache.put("v", makeStream(title: "cached"), now: now)
        #expect(StreamCache.get("v", now: now)?.title == "cached")
    }

    @Test func expiresOnTheStreamFreshnessClock() {
        StreamCache.removeAll()
        let resolved = Date()
        StreamCache.put("v", makeStream(), now: resolved)
        let later = resolved.addingTimeInterval(StreamFreshness.maxAge + 1)
        #expect(StreamCache.get("v", now: later) == nil)
    }

    @Test func missForUnknownId() {
        StreamCache.removeAll()
        #expect(StreamCache.get("nope") == nil)
    }

    @Test func evictsOldestWhenFull() {
        StreamCache.removeAll()
        let base = Date()
        for i in 0..<StreamCache.maxEntries {
            StreamCache.put("v\(i)", makeStream(), now: base.addingTimeInterval(Double(i)))
        }
        StreamCache.put("overflow", makeStream(), now: base.addingTimeInterval(1000))
        #expect(StreamCache.get("v0", now: base.addingTimeInterval(1000)) == nil)  // oldest evicted
        #expect(StreamCache.get("overflow", now: base.addingTimeInterval(1000)) != nil)
        #expect(StreamCache.entries.count == StreamCache.maxEntries)
    }

    @Test func updatingExistingIdDoesNotEvict() {
        StreamCache.removeAll()
        let base = Date()
        for i in 0..<StreamCache.maxEntries {
            StreamCache.put("v\(i)", makeStream(), now: base.addingTimeInterval(Double(i)))
        }
        StreamCache.put("v3", makeStream(title: "updated"), now: base.addingTimeInterval(500))
        #expect(StreamCache.entries.count == StreamCache.maxEntries)
        #expect(StreamCache.get("v3", now: base.addingTimeInterval(500))?.title == "updated")
    }
}
