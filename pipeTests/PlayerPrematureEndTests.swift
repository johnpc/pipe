import Testing
import Foundation
@testable import pipe

@MainActor
struct PlayerPrematureEndTests {
    /// Builds a player whose diagnostic events land in an inspectable buffer.
    private func playerWithLog() -> (PlayerState, RingBufferSink) {
        let buffer = RingBufferSink(capacity: 100)
        let player = isolatedPlayer()
        player.log = PlaybackLog(buffer: buffer, now: { Date(timeIntervalSince1970: 0) })
        return (player, buffer)
    }

    @Test func prematureEndReloadsSameItemInsteadOfAdvancing() {
        let (player, buffer) = playerWithLog()
        player.addToQueue(videoId: "long", url: "bad://long", title: "Long", artist: "x", thumbnail: "", duration: 3600)
        player.addToQueue(videoId: "next", url: "bad://next", title: "Next", artist: "x", thumbnail: "", duration: 60)
        // End fires at 30 min on a 1-hour item → premature.
        player.handleProgress(currentTime: 1800, itemDuration: 3600)
        player.handlePlaybackEnded()
        // Still on the same item (not advanced), and a recovery was logged.
        #expect(player.currentIndex == 0)
        #expect(player.queue.first?.videoId == "long")
        #expect(player.prematureEndRetries == 1)
        #expect(buffer.exportText().contains("recover reload"))
        // The reload resumes from where it died.
        #expect(player.pendingSeek == nil) // consumed by playItem
        #expect(player.currentTime == 1800)
    }

    @Test func prematureEndGivesUpAfterMaxRetriesAndAdvances() {
        let (player, _) = playerWithLog()
        player.addToQueue(videoId: "long", url: "bad://long", title: "Long", artist: "x", thumbnail: "", duration: 3600)
        player.addToQueue(videoId: "next", url: "bad://next", title: "Next", artist: "x", thumbnail: "", duration: 60)
        player.prematureEndRetries = EndOfItemPolicy.maxRetries // exhausted
        player.handleProgress(currentTime: 1800, itemDuration: 3600)
        player.handlePlaybackEnded()
        // Out of retries: finished item dropped, advanced to the next.
        #expect(player.queue.map(\.videoId) == ["next"])
        #expect(player.currentIndex == 0)
    }

    @Test func genuineFinishResetsRetryCounter() {
        let (player, _) = playerWithLog()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 100)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 100)
        player.prematureEndRetries = 1 // a prior recovery happened
        player.handleProgress(currentTime: 100, itemDuration: 100) // played to end
        player.handlePlaybackEnded()
        #expect(player.prematureEndRetries == 0)
        #expect(player.queue.map(\.videoId) == ["b"])
    }

    @Test func playItemLogsStartWithSource() {
        let (player, buffer) = playerWithLog()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        let text = buffer.exportText()
        #expect(text.contains("[play] start"))
        #expect(text.contains("videoId=v"))
        #expect(text.contains("source=stream"))
    }
}
