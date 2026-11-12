import Testing
import Foundation
@testable import pipe

/// Prefetching the next item's stream URL before the current one ends. Stubs
/// the shared `PipedAPI.session`, so it nests under `PipedAPITests` to inherit
/// its `.serialized` trait (see `PlaybackEnqueueNetworkTests`).
extension PipedAPITests {
@MainActor
@Suite(.serialized)
struct PlayerPrefetchTests {
    private static let streamJSON = """
    {"title":"Song","description":null,"uploader":"Artist","uploaderUrl":null,"duration":120,"hls":null,"audioStreams":[],"videoStreams":[{"url":"https://x/fresh.mp4","quality":"360p","mimeType":"video/mp4","videoOnly":false}],"thumbnailUrl":"t","uploadDate":null}
    """

    private func playerNearTheEnd() -> (PlayerState, RingBufferSink) {
        let buffer = RingBufferSink(capacity: 100)
        let player = isolatedPlayer()
        player.log = PlaybackLog(buffer: buffer)
        player.addToQueue(videoId: "now", url: "bad://now", title: "Now", artist: "a", thumbnail: "", duration: 300)
        _ = player.enqueue(.pending(videoId: "next", title: "Next", artist: "a", thumbnail: "", duration: 60, uploadedDate: nil), playNext: false)
        return (player, buffer)
    }

    private func eventually(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<40 where !condition() {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test func tickNearTheEndResolvesTheNextItem() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let (player, buffer) = playerNearTheEnd()

        player.handleProgress(currentTime: 290, itemDuration: 300)
        #expect(player.transition.prefetching == "next")
        await eventually { player.queue[1].resolvedAt != nil }

        #expect(player.queue[1].url == "https://x/fresh.mp4")
        #expect(player.transition.prefetching == nil)
        #expect(buffer.exportText().contains("[prefetch] done"))
        // Now fresh: the hand-off will play it without a fetch.
        #expect(!StreamFreshness.needsRefresh(resolvedAt: player.queue[1].resolvedAt, now: Date(), isLocal: false))
    }

    @Test func repeatedTicksStartOneFetch() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let (player, buffer) = playerNearTheEnd()

        player.handleProgress(currentTime: 290, itemDuration: 300)
        player.handleProgress(currentTime: 291, itemDuration: 300)
        await eventually { player.queue[1].resolvedAt != nil }
        // Once resolved, later ticks see a fresh URL and stay quiet too.
        player.handleProgress(currentTime: 292, itemDuration: 300)
        #expect(buffer.exportText().components(separatedBy: "[prefetch] start").count == 2)
    }

    @Test func failedPrefetchIsLoggedAndNotRetriedEveryTick() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        defer { PipedAPI.session = .shared }
        let (player, buffer) = playerNearTheEnd()

        player.handleProgress(currentTime: 290, itemDuration: 300)
        await eventually { buffer.exportText().contains("[prefetch] failed") }
        player.handleProgress(currentTime: 291, itemDuration: 300)

        #expect(player.queue[1].resolvedAt == nil)
        #expect(player.transition.prefetching == "next")  // parked, not re-fetched
        #expect(buffer.exportText().components(separatedBy: "[prefetch] start").count == 2)
    }

    @Test func finishLeavesAnItemThatStartedPlayingAlone() {
        let (player, _) = playerNearTheEnd()
        var refreshed = player.queue[1]
        refreshed.url = "https://x/late.mp4"
        refreshed.resolvedAt = Date()
        player.currentVideoId = "next"  // user skipped to it meanwhile
        player.finishPrefetch(of: "next", with: refreshed)
        #expect(player.queue[1].url == "")
    }
}
}
