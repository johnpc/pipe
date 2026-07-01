import Testing
import Foundation
@testable import pipe

struct StreamFreshnessTests {
    private let now = Date(timeIntervalSince1970: 100_000)

    @Test func freshWhenResolvedRecently() {
        let recent = now.addingTimeInterval(-60) // 1 min ago
        #expect(StreamFreshness.needsRefresh(resolvedAt: recent, now: now, isLocal: false) == false)
    }

    @Test func staleWhenOlderThanMaxAge() {
        let old = now.addingTimeInterval(-(StreamFreshness.maxAge + 1))
        #expect(StreamFreshness.needsRefresh(resolvedAt: old, now: now, isLocal: false) == true)
    }

    @Test func missingResolvedAtIsStale() {
        // Queue persisted before the field existed → refresh on next play.
        #expect(StreamFreshness.needsRefresh(resolvedAt: nil, now: now, isLocal: false) == true)
    }

    @Test func localFilesNeverRefresh() {
        // Even a nil/old timestamp is fine for a downloaded file.
        #expect(StreamFreshness.needsRefresh(resolvedAt: nil, now: now, isLocal: true) == false)
        let old = now.addingTimeInterval(-100_000)
        #expect(StreamFreshness.needsRefresh(resolvedAt: old, now: now, isLocal: true) == false)
    }

    @Test func boundaryAtExactlyMaxAgeIsStale() {
        let exactly = now.addingTimeInterval(-StreamFreshness.maxAge)
        #expect(StreamFreshness.needsRefresh(resolvedAt: exactly, now: now, isLocal: false) == true)
    }
}

struct QueueItemCodableMigrationTests {
    @Test func newItemHasResolvedAt() {
        let item = QueueItem(videoId: "v", title: "T", artist: "A", thumbnail: "", url: "u", audioUrl: "", duration: 10, uploadedDate: nil)
        #expect(item.resolvedAt != nil)
    }

    @Test func legacyPayloadWithoutResolvedAtDecodesAsStale() throws {
        // A queue item persisted before `resolvedAt` existed must decode to nil so
        // it re-resolves on next play instead of being assumed fresh.
        let legacy = """
        {"videoId":"v","title":"T","artist":"A","thumbnail":"","url":"u","audioUrl":"","duration":10}
        """
        let item = try JSONDecoder().decode(QueueItem.self, from: Data(legacy.utf8))
        #expect(item.resolvedAt == nil)
        #expect(item.videoId == "v")
    }

    @Test func roundTripPreservesResolvedAt() throws {
        // Uses the same plain coders as persistQueue/restoreQueue.
        var item = QueueItem(videoId: "v", title: "T", artist: "A", thumbnail: "", url: "u", audioUrl: "", duration: 10, uploadedDate: nil)
        item.resolvedAt = Date(timeIntervalSince1970: 12345)
        let data = try JSONEncoder().encode(item)
        let back = try JSONDecoder().decode(QueueItem.self, from: data)
        #expect(back.resolvedAt == Date(timeIntervalSince1970: 12345))
    }
}

// Serialized: mutates the shared PipedAPI.session.
@Suite(.serialized)
struct StreamReresolveTests {
    @Test func reresolveReplacesUrlsAndStampsResolvedAt() async throws {
        let json = """
        {"title":"T","description":null,"uploader":"U","uploaderUrl":null,"duration":100,"hls":null,
         "audioStreams":[{"url":"https://fresh.example/audio.m4a","bitrate":128000,"mimeType":"audio/mp4"}],
         "videoStreams":[{"url":"https://fresh.example/video.mp4","quality":"720p","mimeType":"video/mp4","videoOnly":false}],
         "thumbnailUrl":"t","uploadDate":null,"chapters":null,"relatedStreams":null}
        """
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: json)
        defer { PipedAPI.session = .shared }

        let stale = QueueItem(videoId: "abc", title: "Old", artist: "A", thumbnail: "", url: "https://expired/old.mp4", audioUrl: "https://expired/old.m4a", duration: 100, uploadedDate: nil)
        let fresh = try #require(await PlayerState.reresolve(stale))
        #expect(fresh.videoId == "abc")           // identity preserved
        #expect(fresh.url == "https://fresh.example/video.mp4")
        #expect(fresh.audioUrl == "https://fresh.example/audio.m4a")
        #expect(fresh.resolvedAt != nil)          // re-stamped fresh
    }

    @Test func reresolveReturnsNilOnFetchFailure() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: "not json", status: 500)
        defer { PipedAPI.session = .shared }
        let stale = QueueItem(videoId: "abc", title: "Old", artist: "A", thumbnail: "", url: "u", audioUrl: "", duration: 100, uploadedDate: nil)
        let result = await PlayerState.reresolve(stale)
        #expect(result == nil)
    }
}
