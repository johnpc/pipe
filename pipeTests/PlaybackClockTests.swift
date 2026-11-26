import Combine
import Foundation
import Testing
@testable import pipe

/// The once-a-second position update must reach only `PlaybackClock`'s
/// observers. On `PlayerState` it re-rendered every screen each second, which
/// got the app killed for background CPU on 2026-11-26.
@MainActor
struct PlaybackClockTests {
    /// Counts `objectWillChange` emissions while `body` runs.
    private func changes(of object: some ObservableObject, during body: () -> Void) -> Int {
        var count = 0
        let watch = object.objectWillChange.sink { _ in count += 1 }
        body()
        watch.cancel()
        return count
    }

    @Test func progressTicksDoNotRenderThePlayersObservers() {
        let player = isolatedPlayer()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        let playerChanges = changes(of: player) {
            for second in 1...30 { player.handleProgress(currentTime: Double(second), itemDuration: 300) }
        }
        #expect(playerChanges == 0)
        #expect(player.currentTime == 30)
        #expect(player.duration == 300)
    }

    @Test func progressTicksDoReachTheClock() {
        let player = isolatedPlayer()
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        let clockChanges = changes(of: player.clock) {
            for second in 1...3 { player.handleProgress(currentTime: Double(second), itemDuration: 300) }
        }
        #expect(clockChanges == 3)  // the time, once per tick; the unchanged duration not at all
    }

    @Test func durationPublishesOnlyWhenItChanges() {
        let clock = PlaybackClock()
        #expect(changes(of: clock) { clock.setDuration(120); clock.setDuration(120) } == 1)
        #expect(clock.duration == 120)
    }

    @Test func sameChapterDoesNotRepublish() {
        let player = isolatedPlayer()
        player.registerChapters([Chapter(title: "Intro", start: 0, image: nil), Chapter(title: "Next", start: 60, image: nil)], for: "v")
        player.play(videoId: "v", urlString: "bad://v", title: "T", artist: "A", thumbnail: "", duration: 300)
        #expect(changes(of: player) { player.handleProgress(currentTime: 5, itemDuration: 300) } == 0)
        #expect(changes(of: player) { player.handleProgress(currentTime: 61, itemDuration: 300) } == 1)
        #expect(player.currentChapterTitle == "Next")
    }
}
