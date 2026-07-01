import Foundation
import UIKit

/// Wires the opt-in remote diagnostics sink onto the player's log. Kept as a
/// one-shot attach guarded by a flag so toggling the setting repeatedly doesn't
/// stack duplicate uploaders on the shared log.
extension PlayerState {
    /// One-shot per launch: anchor the session with the environment so every
    /// uploaded record can be interpreted (app version, Piped instance, device).
    func logSessionStart(instance: String) {
        guard !sessionStartLogged else { return }
        sessionStartLogged = true
        log.event("session", "start", fields: [
            "appVersion": log.identity.appVersion,
            "instance": instance,
            "os": UIDevice.current.systemVersion,
            "device": UIDevice.current.model,
        ])
    }

    /// Enable remote upload when the user opts in (idempotent). Disabling takes
    /// effect on next launch — a fresh log has no remote sink.
    func syncDiagnosticsUpload(enabled: Bool) {
        guard enabled, !remoteDiagnosticsAttached else { return }
        guard let sink = DiagnosticsConfig.makeRemoteSink(identity: log.identity) else { return }
        log.addSink(sink)
        remoteDiagnosticsAttached = true
        log.event("diagnostics", "remote upload enabled")
    }

    /// Emit a periodic "still playing at T" heartbeat (~every 30s, since the
    /// time observer ticks every 5s). This is the backbone of diagnosis: a
    /// heartbeat trail that stops at 1800s on a 3600s item pinpoints a premature
    /// end, and it keeps a steady event stream flowing for upload during normal
    /// listening — no user interaction required.
    func logProgressHeartbeat(at time: Double) {
        guard isPlaying else { return }
        let bucket = Int(time / 30)
        guard bucket != lastHeartbeatBucket else { return }
        lastHeartbeatBucket = bucket
        log.event("progress", "heartbeat", fields: [
            "at": String(Int(time)),
            "duration": String(Int(duration)),
        ])
    }
}
