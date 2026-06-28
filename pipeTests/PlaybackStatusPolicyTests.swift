import Testing
import AVFoundation
@testable import pipe

struct PlaybackStatusPolicyTests {
    @Test func playingStatusMeansPlaying() {
        #expect(PlaybackStatusPolicy.isPlaying(for: .playing, current: false) == true)
    }

    @Test func pausedStatusMeansNotPlaying() {
        // The crux of the PiP-pause fix: an external pause must be honored, not
        // overridden back to playing.
        #expect(PlaybackStatusPolicy.isPlaying(for: .paused, current: true) == false)
    }

    @Test func waitingKeepsCurrentIntent() {
        // Transient buffering — don't flip the UI either way.
        #expect(PlaybackStatusPolicy.isPlaying(for: .waitingToPlayAtSpecifiedRate, current: true) == true)
        #expect(PlaybackStatusPolicy.isPlaying(for: .waitingToPlayAtSpecifiedRate, current: false) == false)
    }
}

@MainActor
struct PlaybackStatusIntegrationTests {
    @Test func externalPauseSyncsIsPlayingFalse() {
        // Simulates PiP / lock screen pausing the AVPlayer directly: the status
        // observer must adopt the paused state instead of nudging it back on.
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleTimeControlStatus(.paused)
        #expect(player.isPlaying == false)
    }

    @Test func externalResumeSyncsIsPlayingTrue() {
        let player = isolatedPlayer()
        player.isPlaying = false
        player.handleTimeControlStatus(.playing)
        #expect(player.isPlaying == true)
    }

    @Test func bufferingDoesNotFlipState() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleTimeControlStatus(.waitingToPlayAtSpecifiedRate)
        #expect(player.isPlaying == true)
    }

    @Test func stallRecoveryIsNoOpWhenPaused() {
        // A stall notification while the user has paused must not resume playback.
        let player = isolatedPlayer()
        player.isPlaying = false
        player.handlePlaybackStalled()
        #expect(player.isPlaying == false)
    }

    @Test func handlersAreSafeWithoutPlayer() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handlePlaybackStalled()   // no AVPlayer; must not crash
        player.handleTimeControlStatus(.playing)
        #expect(player.isPlaying == true)
    }
}
