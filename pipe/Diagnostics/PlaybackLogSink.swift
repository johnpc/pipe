import Foundation
import os

/// A destination for diagnostic playback events. Kept as a protocol so the
/// on-device buffer, unified logging, and the remote collector (AWS API Gateway
/// + Lambda → S3) are interchangeable without touching any instrumentation.
protocol PlaybackLogSink: AnyObject {
    func write(_ entry: PlaybackLogEntry)
    /// Force any buffered entries to their destination now. No-op for sinks that
    /// write immediately (buffer, unified logging); the remote sink uploads.
    func flush()
}

extension PlaybackLogSink {
    func flush() {}
}

/// Mirrors every entry to Apple's unified logging so it's visible in Console.app
/// and `log stream` (subsystem `com.johncorser.pipe`, category `playback`).
final class OSLogSink: PlaybackLogSink {
    private let logger = Logger(subsystem: "com.johncorser.pipe", category: "playback")

    func write(_ entry: PlaybackLogEntry) {
        logger.log("\(entry.line, privacy: .public)")
    }
}
