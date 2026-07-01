import Testing
import Foundation
@testable import pipe

struct PlaybackLogTests {
    @Test func ringBufferKeepsOnlyMostRecentWithinCapacity() {
        let buffer = RingBufferSink(capacity: 3)
        for i in 1...5 {
            buffer.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: Double(i)), category: "c", message: "\(i)", fields: [:]))
        }
        let messages = buffer.snapshot().map(\.message)
        #expect(messages == ["3", "4", "5"]) // oldest two dropped
    }

    @Test func exportTextJoinsLinesInOrder() {
        let buffer = RingBufferSink(capacity: 10)
        buffer.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "play", message: "start", fields: [:]))
        buffer.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "end", message: "fired", fields: [:]))
        let text = buffer.exportText()
        #expect(text.contains("[play] start"))
        #expect(text.contains("[end] fired"))
        #expect(text.range(of: "[play]")!.lowerBound < text.range(of: "[end]")!.lowerBound)
    }

    @Test func clearEmptiesBuffer() {
        let buffer = RingBufferSink(capacity: 10)
        buffer.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "c", message: "m", fields: [:]))
        buffer.clear()
        #expect(buffer.snapshot().isEmpty)
    }

    @Test func eventFansOutToAllSinks() {
        let buffer = RingBufferSink(capacity: 10)
        let extra = RingBufferSink(capacity: 10)
        let log = PlaybackLog(buffer: buffer, extraSinks: [extra], now: { Date(timeIntervalSince1970: 0) })
        log.event("play", "hello")
        #expect(buffer.snapshot().count == 1)
        #expect(extra.snapshot().count == 1)
        #expect(log.exportText().contains("[play] hello"))
    }
}
