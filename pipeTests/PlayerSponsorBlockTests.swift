import Testing
import Foundation
@testable import pipe

@MainActor
struct PlayerSponsorBlockTests {
    @Test func enabledByDefault() {
        #expect(isolatedPlayer().sponsorBlockEnabled == true)
    }

    @Test func togglePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "sb-\(UUID().uuidString)")!
        let p1 = PlayerState(defaults: suite)
        p1.sponsorBlockEnabled = false
        let p2 = PlayerState(defaults: suite)
        #expect(p2.sponsorBlockEnabled == false)
    }

    @Test func applySkipMovesCurrentTimeToSegmentEnd() {
        let player = isolatedPlayer()
        player.sponsorSegments = [SponsorSegment(start: 10, end: 25)]
        player.applySponsorSkip(at: 12)
        #expect(player.currentTime == 25)
    }

    @Test func applySkipNoOpWhenDisabled() {
        let player = isolatedPlayer()
        player.sponsorBlockEnabled = false
        player.sponsorSegments = [SponsorSegment(start: 10, end: 25)]
        player.currentTime = 12
        player.applySponsorSkip(at: 12)
        #expect(player.currentTime == 12) // unchanged
    }

    @Test func applySkipNoOpOutsideSegment() {
        let player = isolatedPlayer()
        player.sponsorSegments = [SponsorSegment(start: 10, end: 25)]
        player.currentTime = 30
        player.applySponsorSkip(at: 30)
        #expect(player.currentTime == 30)
    }
}
