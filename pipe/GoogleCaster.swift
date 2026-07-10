import Foundation

/// The Cast receiver app id. `CC1AD845` is Google's Default Media Receiver, which
/// plays progressive MP4/HLS out of the box — no Cast Developer Console
/// registration is needed for v1.
let castDefaultReceiverAppID = "CC1AD845"

#if canImport(GoogleCast)
import GoogleCast

/// Production `Casting` backed by the Google Cast SDK. This file (with its
/// `+Listeners` extension) is the only place `GoogleCast`/`GCK*` is imported,
/// keeping those types out of the rest of the app — the same containment
/// `AppleIntelligenceSummarizer` uses for FoundationModels.
///
/// One-time SDK setup (`GCKCastContext.setSharedInstanceWith`) must run once at
/// launch before any instance is created; see `bootstrap()`.
@MainActor
final class GoogleCaster: NSObject, Casting {
    let sessionManager = GCKCastContext.sharedInstance().sessionManager
    let discovery = GCKCastContext.sharedInstance().discoveryManager
    var onStateChange: (() -> Void)?
    var onTimeChange: (() -> Void)?
    /// Provokes the iOS Local Network permission prompt. The Cast SDK's own
    /// discovery does not reliably trigger it, which leaves discovery silently
    /// blocked (deviceCount 0) with no Settings toggle for the user to grant.
    /// Not `private` so `rescan()` in the +Listeners extension can re-trigger it.
    let localNetworkNudge = LocalNetworkNudge()
    let log: PlaybackLog

    init(log: PlaybackLog = .shared) {
        self.log = log
        super.init()
        sessionManager.add(self)
        discovery.add(self)
        // Independent second opinion on discovery: log what a raw NWBrowser (the
        // same mechanism as `dns-sd`) sees, so a Cast-SDK deviceCount of 0 can be
        // told apart from a genuinely empty network.
        localNetworkNudge.onResults = { [weak self] state, count in
            self?.log.event("cast", "nwbrowse", fields: ["state": state, "found": String(count)])
        }
        // Trip the Local Network permission prompt first, then start discovery.
        localNetworkNudge.trigger()
        discovery.startDiscovery()
    }

    var isAvailable: Bool { discovery.hasDiscoveredDevices }
    var deviceName: String? { sessionManager.currentCastSession?.device.friendlyName }

    var connectionState: CastConnectionState {
        switch sessionManager.connectionState {
        case .connected: return .connected
        case .connecting: return .connecting
        default: return .disconnected
        }
    }

    var currentTime: Double {
        sessionManager.currentCastSession?.remoteMediaClient?.approximateStreamPosition() ?? 0
    }

    func presentDevicePicker() {
        // presentCastDialog() silently no-ops when castState is
        // NoDevicesAvailable — the store logs `diagnostics` around this call so a
        // "nothing happens" tap is explained by the actual state.
        GCKCastContext.sharedInstance().presentCastDialog()
    }

    func setHandlers(onStateChange: @escaping () -> Void, onTimeChange: @escaping () -> Void) {
        self.onStateChange = onStateChange
        self.onTimeChange = onTimeChange
    }
}
#else
/// Fallback when the Google Cast SDK isn't linked (CI, or before the binary
/// framework is added in Xcode): never available, so the cast button stays
/// hidden and the app builds/ships unchanged. Mirrors the FoundationModels-absent
/// fallback for `AppleIntelligenceSummarizer`.
@MainActor
final class GoogleCaster: Casting {
    static func bootstrap() {}
    var isAvailable: Bool { false }
    var connectionState: CastConnectionState { .disconnected }
    var deviceName: String? { nil }
    var currentTime: Double { 0 }
    var diagnostics: [String: String] { ["caster": "unlinked"] }
    func load(_ media: CastMedia) {}
    func play() {}
    func pause() {}
    func seek(to time: Double) {}
    func stop() {}
    func presentDevicePicker() {}
    func rescan() {}
    func setHandlers(onStateChange: @escaping () -> Void, onTimeChange: @escaping () -> Void) {}
}
#endif
