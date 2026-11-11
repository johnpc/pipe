import Testing
import Foundation
@testable import pipe

/// Background resolution of pending queue items. Stubs the shared
/// `PipedAPI.session`, so it must never overlap another suite doing the same:
/// nesting it in `PipedAPITests` puts it under that suite's `.serialized`
/// trait (which applies recursively), serializing it with those tests too.
extension PipedAPITests {
@MainActor
@Suite(.serialized)
struct PlaybackEnqueueNetworkTests {

    private static let streamJSON = """
    {"title":"Song","description":null,"uploader":"Artist","uploaderUrl":null,"duration":120,"hls":null,"audioStreams":[],"videoStreams":[{"url":"https://x/full.mp4","quality":"360p","mimeType":"video/mp4","videoOnly":false}],"thumbnailUrl":"t","uploadDate":null}
    """

    private func seeded() -> PlayerState {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "now", url: "bad://now", title: "now", artist: "a", thumbnail: "", duration: 10)
        return player
    }

    private func pending(_ id: String) -> QueueItem {
        .pending(videoId: id, title: "T \(id)", artist: "A", thumbnail: "th", duration: 30, uploadedDate: nil)
    }

    /// Poll (up to ~2s) for a background task's effect to land.
    private func eventually(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<40 where !condition() {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test func resolvePendingFillsInStreamURLs() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = seeded()
        Playback.enqueueNow(pending("vid"), action: .queue, player: player, toast: SpyToast())

        let toast = SpyToast()
        await Playback.resolvePending("vid", player: player, toast: toast)

        #expect(player.queue[1].url == "https://x/full.mp4")
        #expect(player.queue[1].resolvedAt != nil)
        #expect(toast.events.isEmpty)
    }

    @Test func resolvePendingRollsBackTheAddAndNamesTheReason() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        defer { PipedAPI.session = .shared }
        let buffer = RingBufferSink()
        let player = seeded()
        player.log = PlaybackLog(buffer: buffer)
        Playback.enqueueNow(pending("vid"), action: .queue, player: player, toast: SpyToast())

        let toast = SpyToast()
        await Playback.resolvePending("vid", action: .queue, player: player, toast: toast)

        // Same outcome a blocking add had on failure: not queued, reason shown, logged.
        #expect(player.queue.map(\.videoId) == ["now"])
        #expect(toast.events == ["error:Couldn't add — no connection"])
        let entry = buffer.snapshot().first { $0.category == "playbackError" }
        #expect(entry?.message == "queueAddFailed")
        #expect(entry?.fields["videoId"] == "vid")
        #expect(entry?.fields["reason"] == "no connection")
    }

    @Test func resolvePendingReportsAnUnavailableVideo() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: "not a stream") // neither a stream nor an error envelope
        defer { PipedAPI.session = .shared }
        let player = seeded()
        Playback.enqueueNow(pending("gone"), action: .playNext, player: player, toast: SpyToast())

        let toast = SpyToast()
        await Playback.resolvePending("gone", action: .playNext, player: player, toast: toast)

        #expect(player.queue.map(\.videoId) == ["now"])
        #expect(toast.events == ["error:Couldn't add — video unavailable"])
    }

    @Test func resolvePendingLeavesAnItemThatStartedPlayingAlone() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        defer { PipedAPI.session = .shared }
        let player = seeded()
        Playback.enqueueNow(pending("vid"), action: .queue, player: player, toast: SpyToast())
        // The user skips to it before the background fetch finishes.
        player.playIndex(1)
        #expect(player.currentVideoId == "vid")

        let toast = SpyToast()
        await Playback.resolvePending("vid", player: player, toast: toast)

        // Not rolled back from under the player; its own play path reports errors.
        #expect(player.queue.map(\.videoId) == ["now", "vid"])
        #expect(toast.events.isEmpty)
    }

    @Test func performQueueConfirmsBeforeTheNetworkAnswers() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = seeded()
        let toast = SpyToast()

        Playback.perform(pending("vid"), action: .queue, player: player, toast: toast)

        // Synchronous: queued and confirmed with no loading phase.
        #expect(player.queue.map(\.videoId) == ["now", "vid"])
        #expect(toast.events == ["success:Added to Queue"])
        // ...and the URLs arrive in the background.
        await eventually { player.queue.count == 2 && player.queue[1].resolvedAt != nil }
        #expect(player.queue[1].url == "https://x/full.mp4")
    }

    @Test func performQueueOnEmptyQueueFetchesFirst() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = isolatedPlayer()
        let toast = SpyToast()

        Playback.perform(pending("vid"), action: .queue, player: player, toast: toast)

        // Nothing was playing, so the add is a play: loading state, then confirmed.
        await eventually { toast.events.contains("success:Added to Queue") }
        #expect(toast.events.first == "loading:Adding...")
        #expect(player.queue.count == 1)
        #expect(player.currentIndex == 0)
        #expect(player.queue[0].url == "https://x/full.mp4")
    }

    @Test func performQueueOnEmptyQueueReportsAFailedFetch() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.timedOut))
        defer { PipedAPI.session = .shared }
        let player = isolatedPlayer()
        let toast = SpyToast()

        Playback.perform(pending("vid"), action: .queue, player: player, toast: toast)

        await eventually { toast.events.contains("error:Couldn't add — timed out") }
        #expect(player.queue.isEmpty)
    }

    @Test func performPlayNextWhilePlayingIsImmediate() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = seeded()
        Playback.enqueueNow(pending("later"), action: .queue, player: player, toast: SpyToast())
        let toast = SpyToast()

        Playback.perform(pending("next"), action: .playNext, player: player, toast: toast)

        #expect(player.queue.map(\.videoId) == ["now", "next", "later"])
        #expect(toast.events == ["success:Playing Next"])
        await eventually { player.queue[1].resolvedAt != nil }
    }

    @Test func performPlayStillFetchesFirst() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = isolatedPlayer()
        let toast = SpyToast()

        Playback.perform(pending("vid"), action: .play, player: player, toast: toast)

        await eventually { toast.events.contains("success:Now Playing") }
        #expect(toast.events.first == "loading:Loading...")
        #expect(player.queue.count == 1)
        #expect(player.currentIndex == 0)
    }

    @Test func enqueueIntoEmptyQueueStartsPlayingAndResolvesViaThePlayPath() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = isolatedPlayer()

        let needsResolve = Playback.enqueueNow(pending("vid"), action: .queue, player: player, toast: SpyToast())

        // The first item plays right away, showing the row's metadata at once;
        // the stale-URL refresh path (not a second fetch) resolves it.
        #expect(!needsResolve)
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "T vid")
        await eventually { player.queue.first?.resolvedAt != nil }
        #expect(player.queue.first?.url == "https://x/full.mp4")
    }
}
}
