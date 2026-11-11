import Testing
import Foundation
@testable import pipe

/// Instant queueing: inserting is synchronous and network-free. These tests
/// seed the queue with a playing item first so the pending add never becomes
/// the current item (an empty queue would start playing — and fetching — it).
@MainActor
struct PlaybackEnqueueTests {

    private func seeded() -> PlayerState {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "now", url: "bad://now", title: "now", artist: "a", thumbnail: "", duration: 10)
        return player
    }

    private func pending(_ id: String) -> QueueItem {
        .pending(videoId: id, title: "T \(id)", artist: "A", thumbnail: "th", duration: 30, uploadedDate: nil)
    }

    @Test func enqueueNowInsertsImmediatelyWithOnlyASuccessToast() {
        let player = seeded()
        let toast = SpyToast()
        let needsResolve = Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: toast)
        #expect(needsResolve)
        #expect(player.queue.map(\.videoId) == ["now", "v1"])
        #expect(player.queue[1].title == "T v1")
        #expect(player.queue[1].resolvedAt == nil)
        // No "Adding..." phase: the confirmation is the only toast.
        #expect(toast.events == ["success:Added to Queue"])
    }

    @Test func enqueueNowPlayNextInsertsAfterCurrent() {
        let player = seeded()
        Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: SpyToast())
        let toast = SpyToast()
        Playback.enqueueNow(pending("v2"), action: .playNext, player: player, toast: toast)
        #expect(player.queue.map(\.videoId) == ["now", "v2", "v1"])
        #expect(toast.events == ["success:Playing Next"])
    }

    @Test func enqueueNowDuplicateIsNotInsertedTwiceAndNeedsNoResolution() {
        let player = seeded()
        #expect(Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: SpyToast()))
        #expect(!Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: SpyToast()))
        #expect(player.queue.count == 2)
    }

    @Test func applyResolvedURLsFillsThePendingItem() {
        let player = seeded()
        Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: SpyToast())
        let resolved = ResolvedStream(videoId: "v1", url: "https://x/full.mp4", castURL: "https://x/cast.mp4", audioUrl: "https://x/a.m4a", videoOnlyURL: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 30, uploadedDate: nil)
        player.applyResolvedURLs(resolved)
        let item = player.queue[1]
        #expect(item.url == "https://x/full.mp4")
        #expect(item.audioUrl == "https://x/a.m4a")
        #expect(item.castUrl == "https://x/cast.mp4")
        #expect(item.videoOnlyUrl == "https://x/v.mp4")
        #expect(item.resolvedAt != nil)
        #expect(item.title == "T v1") // metadata from the row is kept
    }

    @Test func applyResolvedURLsLeavesTheCurrentItemAlone() {
        let player = seeded()
        let resolved = ResolvedStream(videoId: "now", url: "https://x/new.mp4", audioUrl: "", title: "", artist: "", thumbnail: "", duration: 0, uploadedDate: nil)
        player.applyResolvedURLs(resolved)
        #expect(player.queue[0].url == "bad://now")
    }

    @Test func applyResolvedURLsIgnoresUnknownVideo() {
        let player = seeded()
        let resolved = ResolvedStream(videoId: "ghost", url: "https://x/g.mp4", audioUrl: "", title: "", artist: "", thumbnail: "", duration: 0, uploadedDate: nil)
        player.applyResolvedURLs(resolved)
        #expect(player.queue.count == 1)
    }

    @Test func removePendingDropsQueuedItemButNeverTheCurrentOne() {
        let player = seeded()
        Playback.enqueueNow(pending("v1"), action: .queue, player: player, toast: SpyToast())
        #expect(player.removePending(videoId: "now") == false)
        #expect(player.removePending(videoId: "v1") == true)
        #expect(player.removePending(videoId: "v1") == false)
        #expect(player.queue.map(\.videoId) == ["now"])
    }
}
