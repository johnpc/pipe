import Testing
@testable import pipe

/// `ProcessCPU` turns two CPU-time readings into a percent of one core,
/// the figure each playback heartbeat now carries.
struct ProcessCPUTests {
    /// Scripted readings: each call to the clock returns the next value.
    private final class Script {
        var cpu: [Double]; var wall: [Double]
        init(cpu: [Double], wall: [Double]) { self.cpu = cpu; self.wall = wall }
        func meter() -> ProcessCPU {
            ProcessCPU(cpu: { self.cpu.removeFirst() }, now: { self.wall.removeFirst() })
        }
    }

    @Test func firstSampleHasNothingToCompareWith() {
        var meter = Script(cpu: [1], wall: [100]).meter()
        #expect(meter.sample() == nil)
    }

    @Test func percentOfOneCoreBetweenSamples() {
        // 24 CPU-seconds over 30 wall seconds: 80%, iOS's background kill line.
        var meter = Script(cpu: [10, 34, 37], wall: [100, 130, 160]).meter()
        _ = meter.sample()
        #expect(meter.sample() == 80)
        #expect(meter.sample() == 10)
    }

    @Test func noElapsedTimeYieldsNothing() {
        var meter = Script(cpu: [1, 2], wall: [100, 100]).meter()
        _ = meter.sample()
        #expect(meter.sample() == nil)
    }

    @Test func readsThisProcessesRealCPUTime() {
        let before = ProcessCPU.processSeconds()
        var spin = 0.0
        for i in 0..<200_000 { spin += Double(i).squareRoot() }
        #expect(spin > 0)
        #expect(ProcessCPU.processSeconds() > before)
    }
}
