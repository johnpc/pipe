import Testing
import Foundation
@testable import pipe

@MainActor
struct PlayerStateTests {

    private func enqueue(_ player: PlayerState, _ ids: [String]) {
        for id in ids {
            player.addToQueue(videoId: id, url: "bad://\(id)", title: id, artist: "a", thumbnail: "", duration: 10)
        }
    }

    // MARK: - addToQueue

    @Test func firstAddStartsPlayback() {
        let player = PlayerState()
        enqueue(player, ["a"])
        #expect(player.currentIndex == 0)
        #expect(player.queue.count == 1)
        #expect(player.currentTitle == "a")
    }

    @Test func subsequentAddsDoNotChangeCurrentIndex() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        #expect(player.currentIndex == 0)
        #expect(player.queue.count == 3)
    }

    // MARK: - navigation

    @Test func playNextAndPrevious() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        player.playNext()
        #expect(player.currentIndex == 1)
        player.playNext()
        #expect(player.currentIndex == 2)
        player.playNext() // at end, no-op
        #expect(player.currentIndex == 2)
        player.playPrevious()
        #expect(player.currentIndex == 1)
        player.playPrevious()
        player.playPrevious() // at start, no-op
        #expect(player.currentIndex == 0)
    }

    @Test func playIndexBoundsChecked() {
        let player = PlayerState()
        enqueue(player, ["a", "b"])
        player.playIndex(5)
        #expect(player.currentIndex == 0)
        player.playIndex(-1)
        #expect(player.currentIndex == 0)
        player.playIndex(1)
        #expect(player.currentIndex == 1)
    }

    // MARK: - removeFromQueue

    @Test func removeBeforeCurrentShiftsIndexDown() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(2)
        player.removeFromQueue(at: 0)
        #expect(player.currentIndex == 1)
        #expect(player.queue.count == 2)
    }

    @Test func removeCurrentClampsToLast() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(2)
        player.removeFromQueue(at: 2)
        #expect(player.currentIndex == 1)
        #expect(player.queue.count == 2)
    }

    @Test func removeLastRemainingStops() {
        let player = PlayerState()
        enqueue(player, ["a"])
        player.removeFromQueue(at: 0)
        #expect(player.queue.isEmpty)
        #expect(player.currentIndex == -1)
        #expect(player.isPlaying == false)
    }

    @Test func removeOutOfBoundsNoOp() {
        let player = PlayerState()
        enqueue(player, ["a", "b"])
        player.removeFromQueue(at: 9)
        #expect(player.queue.count == 2)
    }

    @Test func removeViaIndexSet() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c", "d"])
        player.removeFromQueue(at: IndexSet([0, 2]))
        #expect(player.queue.map(\.videoId) == ["b", "d"])
    }

    // MARK: - moveQueueItem

    @Test func moveCurrentItemFollowsIndex() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        // current is a@0; move it to position 2
        player.moveQueueItem(from: IndexSet(integer: 0), to: 3)
        #expect(player.queue.last?.videoId == "a")
        #expect(player.currentIndex == 2)
    }

    @Test func moveItemFromBeforeToAfterCurrentDecrementsIndex() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(1) // current = b
        player.moveQueueItem(from: IndexSet(integer: 0), to: 3) // move a after current
        #expect(player.currentIndex == 0)
        #expect(player.queue[player.currentIndex].videoId == "b")
    }

    @Test func moveItemFromAfterToBeforeCurrentIncrementsIndex() {
        let player = PlayerState()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(1) // current = b
        player.moveQueueItem(from: IndexSet(integer: 2), to: 0) // move c before current
        #expect(player.queue[player.currentIndex].videoId == "b")
    }

    // MARK: - clear / stop / play

    @Test func clearQueueResets() {
        let player = PlayerState()
        enqueue(player, ["a", "b"])
        player.clearQueue()
        #expect(player.queue.isEmpty)
        #expect(player.currentIndex == -1)
        #expect(player.currentTitle == nil)
    }

    @Test func playInsertsAtFrontAndPlays() {
        let player = PlayerState()
        enqueue(player, ["a", "b"])
        player.play(videoId: "z", urlString: "bad://z", title: "Z", artist: "a", thumbnail: "", duration: 5)
        #expect(player.queue.first?.videoId == "z")
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "Z")
    }

    // MARK: - playback controls (no AVPlayer asserts, just state)

    @Test func togglePlayPauseFlipsState() {
        let player = PlayerState()
        player.isPlaying = false
        player.togglePlayPause()
        #expect(player.isPlaying == true)
        player.togglePlayPause()
        #expect(player.isPlaying == false)
    }

    @Test func setSpeedUpdatesPublishedSpeed() {
        let player = PlayerState()
        player.setSpeed(1.5)
        #expect(player.playbackSpeed == 1.5)
    }

    @Test func skipClampsWithinDuration() {
        let player = PlayerState()
        player.duration = 100
        player.currentTime = 50
        player.skip(100)
        #expect(player.currentTime == 100)
        player.skip(-1000)
        #expect(player.currentTime == 0)
    }

    @Test func seekUpdatesCurrentTime() {
        let player = PlayerState()
        player.duration = 100
        player.seek(to: 42)
        #expect(player.currentTime == 42)
    }

    @Test func stopResetsPlaybackState() {
        let player = PlayerState()
        enqueue(player, ["a"])
        player.stop()
        #expect(player.isPlaying == false)
        #expect(player.currentTitle == nil)
        #expect(player.currentTime == 0)
        #expect(player.duration == 0)
    }

    // MARK: - progress / end handlers + recents integration

    private func playerWithRecents() -> (PlayerState, RecentsStore) {
        let suite = UserDefaults(suiteName: "player-\(UUID().uuidString)")!
        let recents = RecentsStore(defaults: suite)
        let player = PlayerState()
        player.recents = recents
        return (player, recents)
    }

    @Test func handleProgressPublishesTimeAndDuration() {
        let (player, recents) = playerWithRecents()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 100)
        player.handleProgress(currentTime: 30, itemDuration: 120)
        #expect(player.currentTime == 30)
        #expect(player.duration == 120)
        #expect(recents.getTimestamp(videoId: "v") == 30)
    }

    @Test func handleProgressIgnoresInvalidDuration() {
        let (player, _) = playerWithRecents()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 100)
        player.duration = 50
        player.handleProgress(currentTime: 10, itemDuration: .nan)
        #expect(player.duration == 50) // unchanged
        player.handleProgress(currentTime: 10, itemDuration: nil)
        #expect(player.duration == 50)
        player.handleProgress(currentTime: 10, itemDuration: 0)
        #expect(player.duration == 50)
    }

    @Test func handlePlaybackEndedMarksCompleteAndAdvances() {
        let (player, recents) = playerWithRecents()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)
        player.handleProgress(currentTime: 8, itemDuration: 10)
        #expect(recents.getTimestamp(videoId: "a") == 8)

        player.handlePlaybackEnded()
        #expect(recents.getTimestamp(videoId: "a") == 0) // marked complete
        #expect(player.currentIndex == 1) // advanced to next
    }
}
