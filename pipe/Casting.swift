import Foundation

/// A receiver's connection lifecycle, mirrored from the phone so the UI can show
/// "connecting…", route transport to the TV, or fall back to local playback.
enum CastConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

/// Everything a Cast receiver needs to start an item. Built by `CastLogic` from a
/// resolved stream — always the full A/V video URL (never audio-only), since we
/// cast to a TV. `startTime` lets a mid-video handoff resume where the phone was.
struct CastMedia: Equatable {
    let url: String
    let contentType: String
    let title: String
    let artist: String
    let thumbnail: String
    let startTime: Double
}

/// Abstraction over the Google Cast SDK so `CastStore` and the playback-routing
/// logic are testable without the closed-source framework. The production impl
/// (`GoogleCaster`) is the only place `GoogleCast`/`GCK*` is imported; tests use
/// `MockCaster`. Mirrors the `Summarizing` protocol over Apple Intelligence.
@MainActor
protocol Casting: AnyObject {
    /// Whether a receiver has been discovered on the network (drives button
    /// visibility — the cast glyph stays hidden until a device is reachable).
    var isAvailable: Bool { get }
    /// Current session state; the store republishes this so views can react.
    var connectionState: CastConnectionState { get }
    /// Human-readable name of the connected device, when any.
    var deviceName: String? { get }
    /// Current playback position on the receiver (seconds), for mirroring the
    /// phone's scrubber and resuming locally when the session ends.
    var currentTime: Double { get }

    /// Push a media item to the receiver and start playback.
    func load(_ media: CastMedia)
    func play()
    func pause()
    func seek(to time: Double)
    /// End playback on the receiver (leaves the session up for the next load).
    func stop()
    /// Present the system Cast device picker so the user can connect to a TV.
    /// Used by the row-level "Cast" affordance (the full-player button uses the
    /// SDK's own `GCKUICastButton`, which presents its own picker).
    func presentDevicePicker()

    /// Called by the store on init to receive state-change and time callbacks.
    /// The impl invokes these on the main actor whenever the SDK reports a change.
    func setHandlers(onStateChange: @escaping () -> Void, onTimeChange: @escaping () -> Void)
}

/// An inert caster: never available, connects to nothing, ignores transport.
/// Used under UI tests so no Cast SDK context is created (which would raise the
/// local-network permission alert and crash if the SDK weren't bootstrapped).
@MainActor
final class NoopCaster: Casting {
    var isAvailable: Bool { false }
    var connectionState: CastConnectionState { .disconnected }
    var deviceName: String? { nil }
    var currentTime: Double { 0 }
    func load(_ media: CastMedia) {}
    func play() {}
    func pause() {}
    func seek(to time: Double) {}
    func stop() {}
    func presentDevicePicker() {}
    func setHandlers(onStateChange: @escaping () -> Void, onTimeChange: @escaping () -> Void) {}
}
