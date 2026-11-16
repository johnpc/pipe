import Testing
import Foundation
@testable import pipe

struct StreamResolverTests {
    private let response = StreamResponse(
        title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 100, hls: "https://y/master.m3u8",
        audioStreams: [AudioStream(url: "https://fresh/a.m4a", bitrate: 128_000, mimeType: "audio/mp4")],
        videoStreams: [VideoStream(url: "https://fresh/v.mp4", quality: "720p", mimeType: "video/mp4", videoOnly: false)],
        thumbnailUrl: "t", uploadDate: nil, chapters: nil, relatedStreams: nil)
    private let stale = QueueItem(videoId: "abc", title: "Old", artist: "A", thumbnail: "", url: "https://expired/old.mp4",
                                  audioUrl: "https://expired/old.m4a", duration: 100, uploadedDate: nil, resolvedAt: nil)

    @Test func applyCopiesEveryURLAndStampsTheTime() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let fresh = try #require(PipedStreamResolver.apply(response, to: stale, language: "en", now: now))
        #expect(fresh.videoId == "abc" && fresh.title == "Old")  // identity preserved
        #expect(fresh.url == "https://fresh/v.mp4")
        #expect(fresh.audioUrl == "https://fresh/a.m4a")
        #expect(fresh.hlsUrl == "https://y/master.m3u8")
        #expect(fresh.resolvedAt == now)
    }

    @Test func applyReturnsNilWhenNothingIsPlayable() {
        let empty = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 1, hls: nil,
                                   audioStreams: [], videoStreams: [], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
        #expect(PipedStreamResolver.apply(empty, to: stale, language: "en") == nil)
    }
}

/// `PlayerState` with an injected resolver: the recovery paths end to end,
/// without stubbing the network.
@MainActor
struct PlayerResolverTests {
    private func player(_ resolver: MockStreamResolver) -> (PlayerState, RingBufferSink) {
        let buffer = RingBufferSink(capacity: 100)
        let p = isolatedPlayer()
        p.resolver = resolver
        p.log = PlaybackLog(buffer: buffer)
        return (p, buffer)
    }

    private func eventually(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<60 where !condition() { try? await Task.sleep(nanoseconds: 50_000_000) }
    }

    @Test func aPendingItemResolvesThenLoads() async {
        let resolver = MockStreamResolver()
        let (p, _) = player(resolver)
        _ = p.enqueue(.pending(videoId: "v", title: "T", artist: "a", thumbnail: "", duration: 60, uploadedDate: nil), playNext: false)
        #expect(p.phase == .resolving)       // spinner + pause glyph while the URL is fetched
        #expect(p.isPlaying && p.isBuffering)
        await eventually { p.phase != .resolving }
        #expect(resolver.requested == ["v"])
        #expect(p.queue[0].url == "https://fresh.example/a.m4a")
        #expect(p.phase == .buffering)       // player built from the fresh URL
    }

    @Test func aFailedRefreshFallsBackToTheStoredURL() async {
        let (p, buffer) = player(MockStreamResolver(freshURL: nil))
        var item = QueueItem(videoId: "v", title: "T", artist: "a", thumbnail: "", url: "https://stored/v.mp4", audioUrl: "", duration: 60, uploadedDate: nil)
        item.resolvedAt = Date(timeIntervalSinceNow: -7_200)  // stale
        _ = p.enqueue(item, playNext: false)
        await eventually { p.phase != .resolving }
        #expect(buffer.exportText().contains("refresh failed, using stored url"))
        #expect(p.phase == .buffering)
    }

    @Test func playAfterGivingUpStartsOverWithAFreshURL() async {
        let resolver = MockStreamResolver()
        let (p, buffer) = player(resolver)
        p.addToQueue(videoId: "dead", url: "bad://dead", title: "Dead", artist: "x", thumbnail: "", duration: 60)
        p.itemFailureRetries = ItemFailurePolicy.maxRetries
        p.handleItemFailure()
        #expect(p.phase.isFailed)
        p.resume()                              // the user taps play on the failed item
        #expect(p.phase == .resolving)
        #expect(buffer.exportText().contains("retry after failure"))
        await eventually { p.phase != .resolving }
        #expect(resolver.requested == ["dead"])
        #expect(p.phase == .buffering)
    }

    @Test func aStaleItemWhileCastingRefreshesBeforeHandingOff() async {
        let resolver = MockStreamResolver()
        let (p, _) = player(resolver)
        var item = QueueItem(videoId: "v", title: "T", artist: "a", thumbnail: "", url: "https://stored/v.mp4", audioUrl: "", duration: 60, uploadedDate: nil)
        item.resolvedAt = nil
        _ = p.enqueue(item, playNext: false)
        await eventually { p.phase != .resolving }
        #expect(resolver.requested == ["v"])
    }
}
