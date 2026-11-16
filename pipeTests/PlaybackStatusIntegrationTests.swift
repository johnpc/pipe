import Testing
import AVFoundation
@testable import pipe

/// `timeControlStatus` adoption through the lifecycle (the PiP-pause fix): an
/// external pause is honored, waiting never flips intent, playing is adopted.
@MainActor
struct PlaybackStatusIntegrationTests {
    @Test func externalPauseSyncsIsPlayingFalse() {
        // Simulates PiP / lock screen pausing the AVPlayer directly: the status
        // observer must adopt the paused state instead of nudging it back on.
        let player = isolatedPlayer()
        player.setPhase(.playing)
        player.handleTimeControlStatus(.paused)
        #expect(player.isPlaying == false)
    }

    @Test func externalResumeSyncsIsPlayingTrue() {
        let player = isolatedPlayer()
        player.setPhase(.paused)
        player.handleTimeControlStatus(.playing)
        #expect(player.isPlaying == true)
    }

    @Test func bufferingDoesNotFlipState() {
        let player = isolatedPlayer()
        player.setPhase(.playing)
        player.handleTimeControlStatus(.waitingToPlayAtSpecifiedRate)
        #expect(player.isPlaying == true)
    }

    @Test func stallRecoveryIsNoOpWhenPaused() {
        // A stall notification while the user has paused must not resume playback.
        let player = isolatedPlayer()
        player.setPhase(.paused)
        player.handlePlaybackStalled()
        #expect(player.isPlaying == false)
    }

    @Test func handlersAreSafeWithoutPlayer() {
        let player = isolatedPlayer()
        player.setPhase(.playing)
        player.handlePlaybackStalled()   // no AVPlayer; must not crash
        player.handleTimeControlStatus(.playing)
        #expect(player.isPlaying == true)
    }
}
