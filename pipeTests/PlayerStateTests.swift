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
        let player = isolatedPlayer()
        enqueue(player, ["a"])
        #expect(player.currentIndex == 0)
        #expect(player.queue.count == 1)
        #expect(player.currentTitle == "a")
    }

    @Test func subsequentAddsDoNotChangeCurrentIndex() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        #expect(player.currentIndex == 0)
        #expect(player.queue.count == 3)
    }

    // MARK: - navigation

    @Test func playNextAndPrevious() {
        let player = isolatedPlayer()
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
        let player = isolatedPlayer()
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
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(2)
        player.removeFromQueue(at: 0)
        #expect(player.currentIndex == 1)
        #expect(player.queue.count == 2)
    }

    @Test func removeCurrentClampsToLast() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(2)
        player.removeFromQueue(at: 2)
        #expect(player.currentIndex == 1)
        #expect(player.queue.count == 2)
    }

    @Test func removeCurrentWhilePlayingMovesToNextItem() {
        // Regression: removing the now-playing row left its audio running as a
        // ghost while the queue no longer contained it.
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.isPlaying = true
        player.removeFromQueue(at: 0)
        #expect(player.queue.map(\.videoId) == ["b", "c"])
        #expect(player.currentIndex == 0)
        #expect(player.currentVideoId == "b")  // actually switched to b
        #expect(player.currentTitle == "b")
    }

    @Test func removeCurrentWhilePausedUpdatesMetadataWithoutPlaying() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b"])
        player.isPlaying = false
        player.removeFromQueue(at: 0)
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "b")
        #expect(player.currentVideoId == "b")
        #expect(player.isPlaying == false)
        #expect(player.player == nil)  // ghost player released
    }

    @Test func removeLastRemainingStops() {
        let player = isolatedPlayer()
        enqueue(player, ["a"])
        player.removeFromQueue(at: 0)
        #expect(player.queue.isEmpty)
        #expect(player.currentIndex == -1)
        #expect(player.isPlaying == false)
    }

    @Test func removeOutOfBoundsNoOp() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b"])
        player.removeFromQueue(at: 9)
        #expect(player.queue.count == 2)
    }

    @Test func removeViaIndexSet() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c", "d"])
        player.removeFromQueue(at: IndexSet([0, 2]))
        #expect(player.queue.map(\.videoId) == ["b", "d"])
    }

    // MARK: - moveQueueItem

    @Test func moveCurrentItemFollowsIndex() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        // current is a@0; move it to position 2
        player.moveQueueItem(from: IndexSet(integer: 0), to: 3)
        #expect(player.queue.last?.videoId == "a")
        #expect(player.currentIndex == 2)
    }

    @Test func moveItemFromBeforeToAfterCurrentDecrementsIndex() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(1) // current = b
        player.moveQueueItem(from: IndexSet(integer: 0), to: 3) // move a after current
        #expect(player.currentIndex == 0)
        #expect(player.queue[player.currentIndex].videoId == "b")
    }

    @Test func moveItemFromAfterToBeforeCurrentIncrementsIndex() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.playIndex(1) // current = b
        player.moveQueueItem(from: IndexSet(integer: 2), to: 0) // move c before current
        #expect(player.queue[player.currentIndex].videoId == "b")
    }

    // MARK: - clear / stop / play

    @Test func clearQueueResets() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b"])
        player.clearQueue()
        #expect(player.queue.isEmpty)
        #expect(player.currentIndex == -1)
        #expect(player.currentTitle == nil)
    }

    @Test func playInsertsAtFrontAndPlays() {
        let player = isolatedPlayer()
        enqueue(player, ["a", "b"])
        player.play(videoId: "z", urlString: "bad://z", title: "Z", artist: "a", thumbnail: "", duration: 5)
        #expect(player.queue.first?.videoId == "z")
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "Z")
    }

    @Test func playAnAlreadyQueuedVideoPlaysInPlaceWithoutDuplicating() {
        // Regression: play() blindly inserted at the front, so playing a video
        // that was already queued produced two queue entries for the same id.
        let player = isolatedPlayer()
        enqueue(player, ["a", "b", "c"])
        player.play(videoId: "b", urlString: "bad://b-fresh", title: "b", artist: "a", thumbnail: "", duration: 10)
        #expect(player.queue.map(\.videoId) == ["a", "b", "c"])
        #expect(player.currentIndex == 1)
        #expect(player.queue[1].url == "bad://b-fresh")  // fresh URL adopted
    }

    // MARK: - current chapter label

    @Test func currentChapterTitleTracksPlaybackTime() {
        let player = isolatedPlayer()
        let chapters = [
            Chapter(title: "Intro", start: 0, image: nil),
            Chapter(title: "Middle", start: 60, image: nil),
            Chapter(title: "End", start: 120, image: nil),
        ]
        player.registerChapters(chapters, for: "v")
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        // play() resets to t=0 → first chapter.
        #expect(player.currentChapterTitle == "Intro")
        player.handleProgress(currentTime: 65, itemDuration: 300)
        #expect(player.currentChapterTitle == "Middle")
        player.handleProgress(currentTime: 200, itemDuration: 300)
        #expect(player.currentChapterTitle == "End")
    }

    @Test func currentChapterTitleNilWithoutChapters() {
        let player = isolatedPlayer()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        player.handleProgress(currentTime: 50, itemDuration: 300)
        #expect(player.currentChapterTitle == nil)
    }

    @Test func registerChaptersIgnoresEmpty() {
        let player = isolatedPlayer()
        player.registerChapters([], for: "v")
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 10)
        #expect(player.currentChapterTitle == nil)
    }

    @Test func stopClearsCurrentChapter() {
        let player = isolatedPlayer()
        player.registerChapters([Chapter(title: "A", start: 0, image: nil), Chapter(title: "B", start: 30, image: nil)], for: "v")
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 60)
        #expect(player.currentChapterTitle != nil)
        player.stop()
        #expect(player.currentChapterTitle == nil)
    }

    // MARK: - chapter jump

    @Test func jumpToNewVideoQueuesAndStartsIt() {
        let player = isolatedPlayer()
        player.jumpTo(videoId: "v", url: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300, startAt: 120)
        #expect(player.queue.first?.videoId == "v")
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "T")
    }

    @Test func jumpToCurrentVideoSeeksInPlace() {
        let player = isolatedPlayer()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        let countBefore = player.queue.count
        player.jumpTo(videoId: "v", url: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300, startAt: 90)
        // Same item: no new queue entry, current time moved.
        #expect(player.queue.count == countBefore)
        #expect(player.currentTime == 90)
    }

    // MARK: - playback controls (no AVPlayer asserts, just state)

    @Test func togglePlayPauseFlipsState() {
        let player = isolatedPlayer()
        player.isPlaying = false
        player.togglePlayPause()
        #expect(player.isPlaying == true)
        player.togglePlayPause()
        #expect(player.isPlaying == false)
    }

    @Test func setSpeedUpdatesPublishedSpeed() {
        let player = isolatedPlayer()
        player.setSpeed(1.5)
        #expect(player.playbackSpeed == 1.5)
    }

    @Test func playbackSpeedPersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "speed-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.setSpeed(2.0)
        let p2 = PlayerState(defaults: suite)
        #expect(p2.playbackSpeed == 2.0)
    }

    @Test func defaultSpeedIsOneWhenNoneSaved() {
        let player = isolatedPlayer()
        #expect(player.playbackSpeed == 1.0)
    }

    @Test func skipClampsWithinDuration() {
        let player = isolatedPlayer()
        player.duration = 100
        player.currentTime = 50
        player.skip(100)
        #expect(player.currentTime == 100)
        player.skip(-1000)
        #expect(player.currentTime == 0)
    }

    @Test func skipForwardWorksBeforeDurationIsKnown() {
        // Regression: with duration still 0 (cold restore / item loading), a
        // forward skip clamped to min(t+10, 0) and snapped playback to 0:00.
        let player = isolatedPlayer()
        player.duration = 0
        player.currentTime = 50
        player.skip(10)
        #expect(player.currentTime == 60)
    }

    @Test func seekUpdatesCurrentTime() {
        let player = isolatedPlayer()
        player.duration = 100
        player.seek(to: 42)
        #expect(player.currentTime == 42)
    }

    @Test func stopResetsPlaybackState() {
        let player = isolatedPlayer()
        enqueue(player, ["a"])
        player.stop()
        #expect(player.isPlaying == false)
        #expect(player.currentTitle == nil)
        #expect(player.currentTime == 0)
        #expect(player.duration == 0)
        // Item-scoped state must not leak into the next session.
        #expect(player.currentVideoId == nil)
        #expect(player.expectedDuration == nil)
        #expect(player.sponsorSegments.isEmpty)
    }

    // MARK: - progress / end handlers + recents integration

    private func playerWithRecents() -> (PlayerState, RecentsStore) {
        let suite = UserDefaults(suiteName: "player-\(UUID().uuidString)")!
        let recents = RecentsStore(defaults: suite)
        let player = isolatedPlayer()
        player.recents = recents
        return (player, recents)
    }

    @Test func playSeedsDurationForLockScreenBeforeFirstTick() {
        // Regression: the lock screen showed no total/elapsed time in the window
        // before AVPlayer loaded its duration. playItem must seed duration from
        // the Piped-reported length immediately (no progress tick yet).
        let player = isolatedPlayer()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 3600)
        #expect(player.duration == 3600)
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

    @Test func handlePlaybackEndedMarksCompleteAndRemovesFromQueue() {
        let (player, recents) = playerWithRecents()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)
        player.handleProgress(currentTime: 8, itemDuration: 10)
        #expect(recents.getTimestamp(videoId: "a") == 8)

        player.handlePlaybackEnded()
        #expect(recents.getTimestamp(videoId: "a") == 0) // marked complete in history
        // Finished item dropped from the queue; next item shifts into slot 0.
        #expect(player.queue.map(\.videoId) == ["b"])
        #expect(player.currentIndex == 0)
    }

    @Test func handlePlaybackEndedOnLastItemStops() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "only", url: "bad://only", title: "Only", artist: "x", thumbnail: "", duration: 10)
        player.handleProgress(currentTime: 10, itemDuration: 10) // played to the end
        player.handlePlaybackEnded()
        #expect(player.queue.isEmpty)
        #expect(player.currentIndex == -1)
        #expect(player.isPlaying == false)
    }

    @Test func stopAfterCurrentEpisodeStopsInsteadOfAdvancing() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)
        player.handleProgress(currentTime: 10, itemDuration: 10) // played to the end
        player.stopAfterCurrentEpisode = true
        player.handlePlaybackEnded()
        // Finished item removed, but playback stopped rather than advancing to b.
        #expect(player.queue.map(\.videoId) == ["b"])
        #expect(player.isPlaying == false)
        #expect(player.stopAfterCurrentEpisode == false) // one-shot, reset
    }

    @Test func addToQueueDeduplicates() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "a", url: "bad://a2", title: "A again", artist: "x", thumbnail: "", duration: 10)
        #expect(player.queue.count == 1)
        #expect(player.queue.first?.title == "A")
    }

    @Test func playNextInsertsAfterCurrent() {
        let player = isolatedPlayer()
        // a (current, index 0), b, c appended.
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "c", url: "bad://c", title: "C", artist: "x", thumbnail: "", duration: 10)
        // Play "z" next → should land right after the current item (index 1).
        player.playNextInQueue(videoId: "z", url: "bad://z", title: "Z", artist: "x", thumbnail: "", duration: 10)
        #expect(player.queue.map(\.videoId) == ["a", "z", "b", "c"])
        #expect(player.currentIndex == 0) // current unchanged
    }

    @Test func playNextDeduplicates() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.playNextInQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        #expect(player.queue.count == 1)
    }

    @Test func playNextOnEmptyQueueStartsPlaying() {
        let player = isolatedPlayer()
        player.playNextInQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        #expect(player.queue.count == 1)
        #expect(player.currentIndex == 0)
    }

    // MARK: - error path

    @Test func playItemSetsErrorOnUnplayableURL() {
        let player = isolatedPlayer()
        // A queue item whose only URL is empty cannot become a valid URL.
        player.addToQueue(videoId: "v", url: "", title: "Broken", artist: "x", thumbnail: "", duration: 0)
        #expect(player.error != nil)
        #expect(player.error?.contains("Broken") == true)
    }

    // MARK: - queue persistence

    @Test func queuePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "persist-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        p1.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)

        let p2 = PlayerState(defaults: suite)
        #expect(p2.queue.count == 2)
        #expect(p2.queue.map(\.videoId) == ["a", "b"])
        #expect(p2.currentIndex == 0)
        // Restored paused, surfacing now-playing metadata without auto-playing.
        #expect(p2.currentTitle == "A")
        #expect(p2.isPlaying == false)
    }

    @Test func resumeAfterRestoreStartsCurrentItem() {
        // Regression: after a cold launch the queue is restored but player is nil;
        // resume() must start the current item, not silently no-op.
        let suite = UserDefaults(suiteName: "resume-restore-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)

        let p2 = PlayerState(defaults: suite)  // fresh: player == nil, queue restored
        #expect(p2.player == nil)
        p2.resume()
        #expect(p2.isPlaying == true)
        #expect(p2.player != nil)  // an item was actually loaded
    }

    @Test func clearedQueueDoesNotRestore() {
        let suite = UserDefaults(suiteName: "persist-clear-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        p1.clearQueue()

        let p2 = PlayerState(defaults: suite)
        #expect(p2.queue.isEmpty)
        #expect(p2.currentIndex == -1)
    }

    // MARK: - video mode toggle

    @Test func toggleVideoModeFlipsAndReloads() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "v", url: "bad://video", audioUrl: "bad://audio", title: "T", artist: "a", thumbnail: "", duration: 100)
        #expect(player.videoMode == false)
        player.toggleVideoMode()
        #expect(player.videoMode == true)
        player.toggleVideoMode()
        #expect(player.videoMode == false)
    }

    @Test func toggleVideoModeKeepsPositionViaPendingSeek() {
        // Regression: the old post-hoc seek() landed on the OLD player when the
        // item took the async stale-URL refresh path, losing the position.
        let player = isolatedPlayer()
        player.addToQueue(videoId: "v", url: "bad://video", audioUrl: "bad://audio", title: "T", artist: "a", thumbnail: "", duration: 100)
        player.handleProgress(currentTime: 42, itemDuration: 100)
        player.toggleVideoMode()
        // playItem consumed the pending seek and restored the position.
        #expect(player.currentTime == 42)
    }

    @Test func videoModePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "vm-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.toggleVideoMode()
        #expect(p1.videoMode == true)
        let p2 = PlayerState(defaults: suite)
        #expect(p2.videoMode == true)
    }

    @Test func toggleVideoModeNoOpWithEmptyQueue() {
        let player = isolatedPlayer()
        player.toggleVideoMode()
        #expect(player.videoMode == true)
        #expect(player.queue.isEmpty)
    }

    // MARK: - sleep timer

    @Test func startSleepTimerSetsRemaining() {
        let player = isolatedPlayer()
        player.startSleepTimer(minutes: 30)
        #expect(player.sleepMinutesRemaining == 30)
    }

    @Test func startSleepTimerNilCancels() {
        let player = isolatedPlayer()
        player.startSleepTimer(minutes: 30)
        player.startSleepTimer(minutes: nil)
        #expect(player.sleepMinutesRemaining == nil)
    }

    @Test func startSleepTimerNonPositiveCancels() {
        let player = isolatedPlayer()
        player.startSleepTimer(minutes: 0)
        #expect(player.sleepMinutesRemaining == nil)
    }

    @Test func tickDecrementsUntilPause() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.isPlaying = true
        player.startSleepTimer(minutes: 2)
        player.tickSleepTimer()
        #expect(player.sleepMinutesRemaining == 1)
        player.tickSleepTimer()
        // Reached zero: timer cleared and playback paused.
        #expect(player.sleepMinutesRemaining == nil)
        #expect(player.isPlaying == false)
    }

    @Test func tickNoOpWhenNoTimer() {
        let player = isolatedPlayer()
        player.tickSleepTimer()
        #expect(player.sleepMinutesRemaining == nil)
    }
}
