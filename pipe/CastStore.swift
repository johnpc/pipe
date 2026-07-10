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
    /// Receiver playback position, republished so the phone's scrubber can mirror
    /// the TV while casting.
    @Published private(set) var currentTime: Double = 0

    private let caster: Casting

    /// Production convenience: back the store with the Google Cast SDK. Tests use
    /// `init(caster:)` with a `MockCaster` instead.
    convenience init() {
        self.init(caster: GoogleCaster())
    }

    init(caster: Casting) {
        self.caster = caster
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

    /// Open the device picker so the user can pick a TV to cast to.
    func presentDevicePicker() { caster.presentDevicePicker() }

    private func syncState() {
        connectionState = caster.connectionState
        deviceName = caster.deviceName
    }

    private func syncTime() {
        currentTime = caster.currentTime
    }
}
