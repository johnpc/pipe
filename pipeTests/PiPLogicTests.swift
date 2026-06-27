import Testing
@testable import pipe

struct PiPLogicTests {
    @Test func eligibleWhenVideoModeAndPlayer() {
        #expect(PiPLogic.isEligible(videoMode: true, hasPlayer: true) == true)
    }

    @Test func notEligibleInAudioMode() {
        #expect(PiPLogic.isEligible(videoMode: false, hasPlayer: true) == false)
    }

    @Test func notEligibleWithoutPlayer() {
        #expect(PiPLogic.isEligible(videoMode: true, hasPlayer: false) == false)
        #expect(PiPLogic.isEligible(videoMode: false, hasPlayer: false) == false)
    }
}
