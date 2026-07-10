import Testing
import Foundation
@testable import pipe

@MainActor
struct CastStoreTests {

    private func makeMedia(url: String = "https://x/v.mp4") -> CastMedia {
        CastLogic.media(url: url, title: "T", artist: "A", thumbnail: "th", startTime: 3)
    }

    // MARK: - Transport forwarding

    @Test func loadForwardsCastableMedia() {
        let caster = MockCaster()
        let store = CastStore(caster: caster)
        store.load(makeMedia())
        #expect(caster.events == ["load"])
        #expect(caster.loaded.first?.url == "https://x/v.mp4")
    }

    @Test func loadDropsEmptyUrl() {
        let caster = MockCaster()
        let store = CastStore(caster: caster)
        store.load(makeMedia(url: ""))
        #expect(caster.events.isEmpty)
    }

    @Test func transportCallsAreForwarded() {
        let caster = MockCaster()
        let store = CastStore(caster: caster)
        store.play()
        store.pause()
        store.seek(to: 20)
        store.stop()
        #expect(caster.events == ["play", "pause", "seek:20.0", "stop"])
    }

    @Test func presentDevicePickerIsForwarded() {
        let caster = MockCaster()
        CastStore(caster: caster).presentDevicePicker()
        #expect(caster.events == ["presentPicker"])
    }

    // MARK: - Published state mirrors the caster

    @Test func isCastingReflectsConnectionState() {
        let caster = MockCaster(connectionState: .disconnected)
        let store = CastStore(caster: caster)
        #expect(store.isCasting == false)
        caster.deviceName = "Shield"
        caster.connectionState = .connected
        #expect(store.isCasting == true)
        #expect(store.connectionState == .connected)
        #expect(store.deviceName == "Shield")
    }

    @Test func availabilityComesFromCaster() {
        #expect(CastStore(caster: MockCaster(isAvailable: false)).isAvailable == false)
        #expect(CastStore(caster: MockCaster(isAvailable: true)).isAvailable == true)
    }

    @Test func currentTimeMirrorsReceiver() {
        let caster = MockCaster()
        let store = CastStore(caster: caster)
        caster.currentTime = 88
        #expect(store.currentTime == 88)
    }
}
