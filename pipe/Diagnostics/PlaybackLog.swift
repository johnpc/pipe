import Foundation

/// Diagnostic logging facade for playback. Instrumentation calls the tiny
/// `event(_:_:fields:)` API; the facade stamps each entry and fans it out to
/// its sinks. A shared instance wires the default sinks (unified logging + an
/// on-device ring buffer the user can export); tests build isolated instances.
final class PlaybackLog {
    /// App-wide logger. The ring buffer backs the Settings "export log" control.
    static let shared = PlaybackLog(
        buffer: RingBufferSink(),
        extraSinks: [OSLogSink()]
    )

    let buffer: RingBufferSink
    /// Stable anonymous identity attached to remote uploads.
    let identity: DeviceIdentity
    private var sinks: [PlaybackLogSink]
    /// Injectable clock so tests get deterministic timestamps.
    private let now: () -> Date

    init(buffer: RingBufferSink,
         extraSinks: [PlaybackLogSink] = [],
         identity: DeviceIdentity = DeviceIdentity(),
         now: @escaping () -> Date = Date.init) {
        self.buffer = buffer
        self.identity = identity
        self.sinks = [buffer] + extraSinks
        self.now = now
    }

    /// Attach an additional sink at runtime (e.g. the opt-in remote uploader).
    func addSink(_ sink: PlaybackLogSink) { sinks.append(sink) }

    /// Record one diagnostic event: a short category, a human summary, and
    /// optional typed fields for structured querying downstream.
    func event(_ category: String, _ message: String, fields: [String: String] = [:]) {
        let entry = PlaybackLogEntry(time: now(), category: category, message: message, fields: fields)
        for sink in sinks { sink.write(entry) }
    }

    /// Force every sink to flush (e.g. the remote uploader). Called by the
    /// "Send Logs" control and app-lifecycle transitions.
    func flush() { for sink in sinks { sink.flush() } }

    /// Text of the on-device buffer, for the Settings share/copy control.
    func exportText() -> String { buffer.exportText() }
}
