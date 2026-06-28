import Testing
import CoreGraphics
@testable import pipe

struct SwipeActionTests {
    @Test func swipeDownDismisses() {
        #expect(SwipeAction.from(translationWidth: 5, translationHeight: 100) == .dismiss)
    }

    @Test func swipeLeftGoesNext() {
        #expect(SwipeAction.from(translationWidth: -100, translationHeight: 5) == .next)
    }

    @Test func smallDragDoesNothing() {
        #expect(SwipeAction.from(translationWidth: 10, translationHeight: 10) == .none)
    }

    @Test func swipeUpDoesNothing() {
        #expect(SwipeAction.from(translationWidth: 0, translationHeight: -100) == .none)
    }

    @Test func swipeRightDoesNothing() {
        #expect(SwipeAction.from(translationWidth: 100, translationHeight: 0) == .none)
    }

    @Test func dominantAxisWins() {
        // Mostly-down with slight left → dismiss (vertical dominates).
        #expect(SwipeAction.from(translationWidth: -30, translationHeight: 100) == .dismiss)
        // Mostly-left with slight down → next (horizontal dominates).
        #expect(SwipeAction.from(translationWidth: -100, translationHeight: 30) == .next)
    }
}

@MainActor
struct SwipeActionApplyTests {
    @Test func dismissClearsQueue() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        let acted = SwipeAction.dismiss.apply(to: player)
        #expect(acted == true)
        #expect(player.queue.isEmpty)
    }

    @Test func nextAdvancesQueue() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.addToQueue(videoId: "b", url: "bad://b", title: "B", artist: "x", thumbnail: "", duration: 10)
        let acted = SwipeAction.next.apply(to: player)
        #expect(acted == true)
        #expect(player.currentIndex == 1)
    }

    @Test func noneDoesNothing() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        let acted = SwipeAction.none.apply(to: player)
        #expect(acted == false)
        #expect(player.queue.count == 1)
    }
}
