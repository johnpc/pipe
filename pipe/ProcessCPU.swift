import Darwin
import Foundation

/// The app's own CPU use between two readings, as a percent of one core.
///
/// iOS kills a background app that averages over 80% for 60 s
/// (`cpu_resource_fatal`), with no error and nothing in our log: the
/// heartbeats just stop. Logging this beside each heartbeat shows the climb
/// on the device itself, before the kill.
struct ProcessCPU {
    /// CPU seconds this process has used (user + system), all threads.
    typealias Clock = () -> Double
    /// Wall-clock seconds; injectable for tests.
    typealias Now = () -> Double

    private let cpu: Clock
    private let now: Now
    private var last: (cpu: Double, wall: Double)?

    init(cpu: @escaping Clock = ProcessCPU.processSeconds, now: @escaping Now = { Date().timeIntervalSince1970 }) {
        self.cpu = cpu
        self.now = now
    }

    /// Percent of one core used since the previous call; nil on the first call
    /// (nothing to compare with) or if no time has passed.
    mutating func sample() -> Int? {
        let current = (cpu: cpu(), wall: now())
        defer { last = current }
        guard let last, current.wall > last.wall else { return nil }
        return Int(((current.cpu - last.cpu) / (current.wall - last.wall) * 100).rounded())
    }

    static func processSeconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}
