import Testing
import AVFoundation
@testable import pipe

struct StallPolicyTests {
    @Test func nudgesWhenIntendingToPlayButPaused() {
        // Involuntary stall: we want to play, player reports paused.
        #expect(StallPolicy.shouldNudge(intendingToPlay: true, status: .paused) == true)
    }

    @Test func doesNotNudgeWhenUserPaused() {
        // Deliberate pause sets intendingToPlay = false first.
        #expect(StallPolicy.shouldNudge(intendingToPlay: false, status: .paused) == false)
    }

    @Test func doesNotNudgeWhilePlaying() {
        #expect(StallPolicy.shouldNudge(intendingToPlay: true, status: .playing) == false)
    }

    @Test func doesNotNudgeWhileAlreadyRecovering() {
        // AVPlayer is buffering back on its own — leave it alone.
        #expect(StallPolicy.shouldNudge(intendingToPlay: true, status: .waitingToPlayAtSpecifiedRate) == false)
    }
}

@MainActor
struct PlayerStallIntegrationTests {
    @Test func handleTimeControlStatusDoesNotCrashWithoutPlayer() {
        let player = isolatedPlayer()
        // No real AVPlayer item; exercising the handler must be safe.
        player.isPlaying = true
        player.handleTimeControlStatus(.paused)
        player.handleTimeControlStatus(.playing)
        #expect(player.isPlaying == true)
    }
}
