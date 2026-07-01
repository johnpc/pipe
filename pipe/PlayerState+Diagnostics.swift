import Foundation

/// Wires the opt-in remote diagnostics sink onto the player's log. Kept as a
/// one-shot attach guarded by a flag so toggling the setting repeatedly doesn't
/// stack duplicate uploaders on the shared log.
extension PlayerState {
    /// Enable remote upload when the user opts in (idempotent). Disabling takes
    /// effect on next launch — a fresh log has no remote sink.
    func syncDiagnosticsUpload(enabled: Bool) {
        guard enabled, !remoteDiagnosticsAttached else { return }
        guard let sink = DiagnosticsConfig.makeRemoteSink(identity: log.identity) else { return }
        log.addSink(sink)
        remoteDiagnosticsAttached = true
        log.event("diagnostics", "remote upload enabled")
    }
}
