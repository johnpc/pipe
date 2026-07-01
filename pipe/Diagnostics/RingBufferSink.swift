import Foundation

/// An in-memory, fixed-capacity sink that keeps the most recent N entries so a
/// user can export a diagnostic log after reproducing a bug — without any data
/// leaving the device. Thread-safe via a serial queue; safe to call from the
/// player's main-actor callbacks and background fetch tasks alike.
final class RingBufferSink: PlaybackLogSink {
    private let capacity: Int
    private var entries: [PlaybackLogEntry] = []
    private let queue = DispatchQueue(label: "com.johncorser.pipe.ringbuffer")

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    func write(_ entry: PlaybackLogEntry) {
        queue.sync {
            entries.append(entry)
            if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
        }
    }

    /// A snapshot of the buffered entries, oldest first.
    func snapshot() -> [PlaybackLogEntry] {
        queue.sync { entries }
    }

    /// The buffered log rendered as newline-joined text, ready to share/copy.
    func exportText() -> String {
        snapshot().map(\.line).joined(separator: "\n")
    }

    func clear() {
        queue.sync { entries.removeAll() }
    }
}
