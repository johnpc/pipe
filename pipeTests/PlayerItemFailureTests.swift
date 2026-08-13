import Testing
import Foundation
@testable import pipe

@MainActor
struct PlayerItemFailureTests {
    /// Builds a player whose diagnostic events land in an inspectable buffer.
    private func playerWithLog() -> (PlayerState, RingBufferSink) {
        let buffer = RingBufferSink(capacity: 100)
        let player = isolatedPlayer()
        player.log = PlaybackLog(buffer: buffer, now: { Date(timeIntervalSince1970: 0) })
        return (player, buffer)
    }

    @Test func failedItemReResolvesInsteadOfStickingAtZero() {
        let (player, buffer) = playerWithLog()
        player.addToQueue(videoId: "dead", url: "bad://dead", title: "Dead", artist: "x", thumbnail: "", duration: 604)
        player.handleItemFailure()
        // Same item, marked stale so playItem mints a fresh URL rather than
        // replaying the dead one.
        #expect(player.currentIndex == 0)
        #expect(player.queue.first?.videoId == "dead")
        #expect(player.queue.first?.resolvedAt == nil)
        #expect(player.itemFailureRetries == 1)
        #expect(buffer.exportText().contains("recovery"))
    }

    @Test func failedItemSurfacesErrorAfterRetriesExhausted() {
        let (player, _) = playerWithLog()
        player.addToQueue(videoId: "dead", url: "bad://dead", title: "Dead Video", artist: "x", thumbnail: "", duration: 604)
        player.itemFailureRetries = ItemFailurePolicy.maxRetries
        player.handleItemFailure()
        // Out of retries: tell the user rather than retrying forever.
        #expect(player.error?.contains("Dead Video") == true)
        #expect(player.isPlaying == false)
        #expect(player.itemFailureRetries == 0)  // budget reset for the next item
    }

    @Test func retryBudgetResetsOnceAnItemPlays() {
        let (player, _) = playerWithLog()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 60)
        player.itemFailureRetries = 1
        player.noteItemPlaying()
        #expect(player.itemFailureRetries == 0)
    }

    @Test func noteItemPlayingIsANoopWhenBudgetUntouched() {
        let (player, _) = playerWithLog()
        player.noteItemPlaying()
        #expect(player.itemFailureRetries == 0)
    }

    @Test func failureWithEmptyQueueIsIgnored() {
        let (player, _) = playerWithLog()
        player.handleItemFailure()  // currentIndex == -1
        #expect(player.error == nil)
        #expect(player.itemFailureRetries == 0)
    }

    @Test func recoveryIsBoundedAndEventuallyGivesUp() {
        let (player, _) = playerWithLog()
        player.addToQueue(videoId: "dead", url: "bad://dead", title: "Dead", artist: "x", thumbnail: "", duration: 604)
        // Every retry keeps quiet and re-resolves…
        for attempt in 1...ItemFailurePolicy.maxRetries {
            player.handleItemFailure()
            #expect(player.error == nil)
            #expect(player.itemFailureRetries == attempt)
        }
        // …until the budget runs out, at which point it reports instead of
        // retrying forever.
        player.handleItemFailure()
        #expect(player.error != nil)
        #expect(player.isPlaying == false)
    }
}
