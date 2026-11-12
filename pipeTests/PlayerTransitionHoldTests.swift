import Testing
import Foundation
import AVFoundation
@testable import pipe

/// The background hold that keeps the app alive while the next item loads.
@MainActor
struct PlayerTransitionHoldTests {
    private func player() -> (PlayerState, MockBackgroundActivity, RingBufferSink) {
        let activity = MockBackgroundActivity()
        let buffer = RingBufferSink(capacity: 100)
        let player = isolatedPlayer()
        player.transition = ItemTransition(activity: activity)
        player.log = PlaybackLog(buffer: buffer, now: { Date(timeIntervalSince1970: 0) })
        return (player, activity, buffer)
    }

    private func twoItems(_ p: PlayerState) {
        p.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 100)
        p.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 100)
    }

    @Test func loadingAnItemTakesTheHold() {
        let (p, activity, buffer) = player()
        twoItems(p)
        #expect(p.transition.isHolding)
        #expect(activity.begun.count == 1)
        #expect(buffer.exportText().contains("[hold] begin"))
    }

    @Test func advancingAtEndOfItemHoldsUntilTheNextOnePlays() {
        let (p, activity, _) = player()
        twoItems(p)
        p.handleTimeControlStatus(.playing)  // first item audible → released
        #expect(!p.transition.isHolding)
        p.handleProgress(currentTime: 100, itemDuration: 100)
        p.handlePlaybackEnded()              // hand-off: load "b"
        #expect(p.queue.map(\.videoId) == ["b"])
        #expect(p.transition.isHolding)
        #expect(activity.begun.count == 2)
        p.handleTimeControlStatus(.playing)
        #expect(!p.transition.isHolding)
        #expect(activity.ended.count == 2)
    }

    @Test func pausedStatusFromTheOldPlayerKeepsTheHold() {
        let (p, _, _) = player()
        twoItems(p)
        p.handleTimeControlStatus(.paused)
        p.handleTimeControlStatus(.waitingToPlayAtSpecifiedRate)
        #expect(p.transition.isHolding)
    }

    @Test func userPauseReleasesTheHold() {
        let (p, _, buffer) = player()
        twoItems(p)
        p.pause()
        #expect(!p.transition.isHolding)
        #expect(buffer.exportText().contains("reason=pause"))
    }

    @Test func stopReleasesTheHold() {
        let (p, _, _) = player()
        twoItems(p)
        p.stop()
        #expect(!p.transition.isHolding)
    }

    @Test func givingUpOnAFailedItemReleasesTheHold() {
        let (p, _, _) = player()
        twoItems(p)
        p.itemFailureRetries = ItemFailurePolicy.maxRetries
        p.handleItemFailure()
        #expect(p.error != nil)
        #expect(!p.transition.isHolding)
    }

    @Test func unplayableURLReleasesTheHold() {
        let (p, _, buffer) = player()
        p.addToQueue(videoId: "bad", url: "", title: "Bad", artist: "x", thumbnail: "", duration: 10)
        #expect(!p.transition.isHolding)
        #expect(buffer.exportText().contains("reason=bad url"))
    }

    @Test func expiredHoldIsLogged() {
        let (p, activity, buffer) = player()
        twoItems(p)
        activity.expire?()
        #expect(!p.transition.isHolding)
        #expect(buffer.exportText().contains("[hold] expired"))
    }

    @Test func releaseWithoutHoldIsSilent() {
        let (p, activity, buffer) = player()
        p.releaseTransitionHold("noop")
        #expect(activity.ended.isEmpty)
        #expect(!buffer.exportText().contains("release"))
    }
}
