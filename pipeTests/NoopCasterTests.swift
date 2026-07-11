import Testing
import Foundation
@testable import pipe

/// The inert caster used under UI tests must be a safe no-op: never available,
/// never connected, and transport calls must not crash or report state.
@MainActor
struct NoopCasterTests {

    @Test func isNeverAvailableOrConnected() {
        let caster = NoopCaster()
        #expect(caster.isAvailable == false)
        #expect(caster.connectionState == .disconnected)
        #expect(caster.deviceName == nil)
        #expect(caster.currentTime == 0)
    }

    @Test func transportCallsAreHarmlessNoops() {
        let caster = NoopCaster()
        // None of these should crash or change observable state.
        caster.load(CastLogic.media(url: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "", startTime: 0))
        caster.play()
        caster.pause()
        caster.seek(to: 30)
        caster.stop()
        caster.presentDevicePicker()
        caster.setHandlers(onStateChange: {}, onTimeChange: {}, onEnded: {})
        #expect(caster.connectionState == .disconnected)
    }

    @Test func drivingCastStoreWithNoopStaysDisconnected() {
        // A CastStore backed by the noop caster reports "not casting", so playback
        // routing falls through to local — the exact behavior we want under tests.
        let store = CastStore(caster: NoopCaster())
        #expect(store.isCasting == false)
        #expect(store.isAvailable == false)
        store.load(CastLogic.media(url: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "", startTime: 0))
        store.play()
        #expect(store.connectionState == .disconnected)
    }
}
