import Foundation
@testable import pipe

/// In-memory `Casting` double: records forwarded calls and lets a test drive the
/// connection state / receiver time, then fire the store's handlers. Mirrors the
/// `MockSummarizer` pattern used for `TranscriptStore`.
@MainActor
final class MockCaster: Casting {
    var isAvailable: Bool
    var connectionState: CastConnectionState { didSet { onStateChange?() } }
    var deviceName: String?
    var currentTime: Double { didSet { onTimeChange?() } }

    /// Recorded transport calls, in order, for assertions.
    private(set) var events: [String] = []
    private(set) var loaded: [CastMedia] = []

    private var onStateChange: (() -> Void)?
    private var onTimeChange: (() -> Void)?

    init(isAvailable: Bool = true,
         connectionState: CastConnectionState = .disconnected,
         deviceName: String? = nil,
         currentTime: Double = 0) {
        self.isAvailable = isAvailable
        self.connectionState = connectionState
        self.deviceName = deviceName
        self.currentTime = currentTime
    }

    func load(_ media: CastMedia) { loaded.append(media); events.append("load") }
    func play() { events.append("play") }
    func pause() { events.append("pause") }
    func seek(to time: Double) { events.append("seek:\(time)") }
    func stop() { events.append("stop") }
    func presentDevicePicker() { events.append("presentPicker") }

    func setHandlers(onStateChange: @escaping () -> Void, onTimeChange: @escaping () -> Void) {
        self.onStateChange = onStateChange
        self.onTimeChange = onTimeChange
    }
}
