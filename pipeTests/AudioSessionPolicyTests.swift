import Testing
import AVFoundation
@testable import pipe

struct AudioSessionPolicyTests {
    @Test func resumesOnlyWhenShouldResumeAndWasPlaying() {
        let resume = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        #expect(AudioSessionPolicy.shouldResumeAfterInterruption(optionsRawValue: resume, wasPlaying: true) == true)
        #expect(AudioSessionPolicy.shouldResumeAfterInterruption(optionsRawValue: resume, wasPlaying: false) == false)
    }

    @Test func doesNotResumeWithoutShouldResumeOption() {
        #expect(AudioSessionPolicy.shouldResumeAfterInterruption(optionsRawValue: 0, wasPlaying: true) == false)
    }

    @Test func pausesOnlyWhenOldDeviceUnavailable() {
        let unplugged = AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        let newDevice = AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue
        #expect(AudioSessionPolicy.shouldPauseOnRouteChange(reasonRawValue: unplugged) == true)
        #expect(AudioSessionPolicy.shouldPauseOnRouteChange(reasonRawValue: newDevice) == false)
    }
}
