import Testing
import Foundation
@testable import pipe

/// Verifies that when a receiver is connected, playback and transport drive the
/// cast session instead of the local AVPlayer.
@MainActor
struct PlayerStateCastTests {

    /// Wire an isolated player to a connected mock caster.
    private func castingPlayer() -> (PlayerState, MockCaster) {
        let player = isolatedPlayer()
        let caster = MockCaster(connectionState: .connected, deviceName: "Shield")
        player.cast = CastStore(caster: caster)
        return (player, caster)
    }

    @Test func playingWhileConnectedLoadsReceiverNotLocalPlayer() {
        let (player, caster) = castingPlayer()
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 30)
        #expect(caster.events.contains("load"))
        #expect(caster.loaded.first?.url == "https://x/v.mp4")
        #expect(player.player == nil)          // no local AVPlayer built
        #expect(player.isPlaying == true)
        #expect(player.currentTitle == "T")
    }

    @Test func pauseAndResumeDriveTheReceiver() {
        let (player, caster) = castingPlayer()
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 30)
        player.pause()
        player.resume()
        #expect(caster.events.contains("pause"))
        #expect(caster.events.contains("play"))
        #expect(player.isPlaying == true)
    }

    @Test func seekDrivesTheReceiver() {
        let (player, caster) = castingPlayer()
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 100)
        player.seek(to: 42)
        #expect(caster.events.contains("seek:42.0"))
        #expect(player.currentTime == 42)
    }

    @Test func receiverTimeMirrorsOntoCurrentTime() {
        let (player, caster) = castingPlayer()
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 100)
        caster.currentTime = 55
        #expect(player.currentTime == 55)
    }

    @Test func stopEndsTheReceiverSession() {
        let (player, caster) = castingPlayer()
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 100)
        player.stop()
        #expect(caster.events.contains("stop"))
    }

    @Test func connectingHandsOffTheCurrentItem() {
        let player = isolatedPlayer()
        let caster = MockCaster(connectionState: .disconnected)
        player.attachCast(CastStore(caster: caster))
        // Start local playback of an item.
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 30)
        #expect(caster.events.isEmpty)   // not casting yet
        // User connects to a TV — the current item should hand off automatically.
        caster.deviceName = "Shield"
        caster.connectionState = .connected
        #expect(caster.loaded.first?.url == "https://x/v.mp4")
        #expect(player.player == nil)
    }

    @Test func repeatedConnectedStatusLoadsReceiverOnlyOnce() {
        // Regression: the receiver republishes `connected` on every media-status
        // callback. Without removeDuplicates + the loaded-id guard, each republish
        // re-ran castItem, aborting the prior loadMedia ("replaced") so playback
        // never started and controls were wiped. It must load exactly once.
        let player = isolatedPlayer()
        let caster = MockCaster(connectionState: .disconnected)
        player.attachCast(CastStore(caster: caster))
        player.play(videoId: "v", urlString: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "th", duration: 30)
        caster.connectionState = .connected
        // Simulate a burst of duplicate status republishes.
        for _ in 0..<10 { caster.connectionState = .connected }
        #expect(caster.events.filter { $0 == "load" }.count == 1)
    }

    @Test func notCastingKeepsLocalBehavior() {
        let player = isolatedPlayer()
        player.cast = CastStore(caster: MockCaster(connectionState: .disconnected))
        #expect(player.isCasting == false)
        player.play(videoId: "v", urlString: "bad://url", title: "T", artist: "A", thumbnail: "", duration: 10)
        // Local path: queued and current, no receiver involvement.
        #expect(player.queue.count == 1)
        #expect(player.currentIndex == 0)
    }

    @Test func rowCastActionPresentsPicker() {
        let player = isolatedPlayer()
        let caster = MockCaster()
        player.attachCast(CastStore(caster: caster))
        Playback.cast(videoId: "v", player: player, toast: SpyToast())
        #expect(caster.events.contains("presentPicker"))
    }
}
