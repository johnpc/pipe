import Foundation
import Combine

/// Observable wrapper around the Cast SDK. Views observe `connectionState` and
/// `isCasting` to show cast UI; playback routing asks `isCasting` to decide
/// whether transport drives the receiver or the local `AVPlayer`. The SDK lives
/// behind the injectable `Casting` dependency so this is testable with a mock,
/// matching how `TranscriptStore` wraps `Summarizing`.
@MainActor
final class CastStore: ObservableObject {
    @Published private(set) var connectionState: CastConnectionState = .disconnected
    @Published private(set) var deviceName: String?
    /// Whether any Cast receiver has been discovered on the network. Drives the
    /// "no devices found" UI and the Search-again affordance.
    @Published private(set) var hasDevices = false
    /// Receiver playback position, republished so the phone's scrubber can mirror
    /// the TV while casting.
    @Published private(set) var currentTime: Double = 0

    private let caster: Casting
    private let log: PlaybackLog

    /// Production convenience: back the store with the Google Cast SDK. Under UI
    /// tests, use an inert caster so no SDK context is created (which would raise
    /// the local-network prompt). Unit tests pass a `MockCaster` via `init(caster:)`.
    convenience init() {
        self.init(caster: MockMode.isEnabled() ? NoopCaster() : GoogleCaster())
    }

    init(caster: Casting, log: PlaybackLog = .shared) {
        self.caster = caster
        self.log = log
        caster.setHandlers(
            onStateChange: { [weak self] in self?.syncState() },
            onTimeChange: { [weak self] in self?.syncTime() }
        )
        syncState()
    }

    nonisolated deinit {}

    /// True once a receiver session is established and transport should target it.
    var isCasting: Bool { connectionState == .connected }

    /// Whether the cast affordance should be offered at all (device on network).
    var isAvailable: Bool { caster.isAvailable }

    /// Push an item to the receiver, guarding against a dead URL so we never load
    /// the TV with an empty source.
    func load(_ media: CastMedia) {
        guard CastLogic.isCastable(media) else { return }
        caster.load(media)
    }

    func play() { caster.play() }
    func pause() { caster.pause() }
    func seek(to time: Double) { caster.seek(to: time) }
    func stop() { caster.stop() }

    /// Open the device picker so the user can pick a TV to cast to. Logs the SDK
    /// state at tap time so a "nothing happens" report is explained by the actual
    /// state (no devices / discovery inactive / permission denied).
    func presentDevicePicker() {
        log.event("cast", "presentPicker", fields: caster.diagnostics)
        caster.presentDevicePicker()
    }

    /// Restart discovery — backs the "Search again" button in the no-devices UI.
    func rescan() {
        log.event("cast", "rescan", fields: caster.diagnostics)
        caster.rescan()
    }

    private func syncState() {
        connectionState = caster.connectionState
        deviceName = caster.deviceName
        hasDevices = caster.isAvailable
    }

    private func syncTime() {
        currentTime = caster.currentTime
    }
}
