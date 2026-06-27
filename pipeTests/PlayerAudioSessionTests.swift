import Testing
import Foundation
import AVFoundation
@testable import pipe

@MainActor
struct PlayerAudioSessionTests {

    private func interruption(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions = []) -> Notification {
        Notification(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: type.rawValue,
            AVAudioSessionInterruptionOptionKey: options.rawValue,
        ])
    }

    private func routeChange(_ reason: AVAudioSession.RouteChangeReason) -> Notification {
        Notification(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [
            AVAudioSessionRouteChangeReasonKey: reason.rawValue,
        ])
    }

    @Test func interruptionBeganPausesAndRemembersState() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleInterruption(interruption(.began))
        #expect(player.isPlaying == false)
        #expect(player.wasPlayingBeforeInterruption == true)
    }

    @Test func interruptionEndedResumesWhenShouldResume() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.handleInterruption(interruption(.began))     // captures wasPlaying = true
        #expect(player.isPlaying == false)
        player.handleInterruption(interruption(.ended, options: .shouldResume))
        #expect(player.isPlaying == true)
    }

    @Test func interruptionEndedDoesNotResumeWithoutOption() {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "a", url: "bad://a", title: "A", artist: "x", thumbnail: "", duration: 10)
        player.handleInterruption(interruption(.began))
        player.handleInterruption(interruption(.ended)) // no .shouldResume
        #expect(player.isPlaying == false)
    }

    @Test func routeChangePausesWhenHeadphonesUnplugged() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleRouteChange(routeChange(.oldDeviceUnavailable))
        #expect(player.isPlaying == false)
    }

    @Test func routeChangeIgnoresOtherReasons() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleRouteChange(routeChange(.newDeviceAvailable))
        #expect(player.isPlaying == true)
    }

    @Test func malformedNotificationsAreIgnored() {
        let player = isolatedPlayer()
        player.isPlaying = true
        player.handleInterruption(Notification(name: AVAudioSession.interruptionNotification))
        player.handleRouteChange(Notification(name: AVAudioSession.routeChangeNotification))
        #expect(player.isPlaying == true)
    }
}
