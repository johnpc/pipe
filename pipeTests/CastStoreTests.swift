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

    @Test func rescanIsForwarded() {
        let caster = MockCaster()
        CastStore(caster: caster).rescan()
        #expect(caster.events == ["rescan"])
    }

    // MARK: - Diagnostics logging (explains a "nothing happens" tap)

    @Test func presentPickerLogsSdkStateSnapshot() {
        let buffer = RingBufferSink(capacity: 10)
        let log = PlaybackLog(buffer: buffer)
        let caster = MockCaster()
        caster.diagnostics = ["castState": "0", "deviceCount": "0", "discoveryActive": "true"]
        CastStore(caster: caster, log: log).presentDevicePicker()
        let entry = buffer.snapshot().first { $0.category == "cast" && $0.message == "presentPicker" }
        #expect(entry != nil)
        #expect(entry?.fields["castState"] == "0")
        #expect(entry?.fields["deviceCount"] == "0")
    }

    @Test func rescanLogsSdkStateSnapshot() {
        let buffer = RingBufferSink(capacity: 10)
        let log = PlaybackLog(buffer: buffer)
        CastStore(caster: MockCaster(), log: log).rescan()
        #expect(buffer.snapshot().contains { $0.category == "cast" && $0.message == "rescan" })
    }

    // MARK: - hasDevices drives the no-devices UI

    @Test func hasDevicesTracksCasterAvailability() {
        let caster = MockCaster(isAvailable: false)
        let store = CastStore(caster: caster)
        #expect(store.hasDevices == false)
        caster.isAvailable = true      // discovery finds a receiver
        #expect(store.hasDevices == true)
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
