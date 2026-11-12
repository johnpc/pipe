import Testing
import Foundation
@testable import pipe

private final class FixtureToken {}

/// Decoding the `sidx` segment index at the head of a fragmented MP4.
struct MP4SegmentIndexTests {
    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "mp4"))
        return try Data(contentsOf: url)
    }

    @Test func readsTheFixtureLayout() throws {
        // composition_video.mp4: ftyp@0:28 moov@28:750 sidx@778:52 moof@830:224 mdat@1054:3686
        let index = try MP4SegmentIndex.parse(try Self.fixture("composition_video"))
        #expect(index.initLength == 778)
        #expect(index.fragments.count == 1)
        #expect(index.fragments.first?.offset == 830)
        #expect(index.fragments.first?.size == 224 + 3686)
        let duration = try #require(index.fragments.first?.duration)
        #expect(duration > 0.5 && duration <= 1.1)
    }

    @Test func parsesAMultiFragmentIndex() throws {
        let data = MP4Fixture.indexed(fragments: [(1000, 90_000), (2000, 90_000), (500, 90_000)], timescale: 90_000)
        let index = try MP4SegmentIndex.parse(data)
        #expect(index.initLength == MP4Fixture.headerLength)
        let sidxEnd = MP4Fixture.headerLength + MP4Fixture.sidxLength(count: 3)
        #expect(index.fragments.map(\.offset) == [sidxEnd, sidxEnd + 1000, sidxEnd + 3000])
        #expect(index.fragments.map(\.duration) == [1, 1, 1])
    }

    @Test func honorsFirstOffsetAndVersion1Fields() throws {
        let data = MP4Fixture.indexed(fragments: [(640, 45_000)], timescale: 90_000, version: 1, firstOffset: 16)
        let index = try MP4SegmentIndex.parse(data)
        let sidxEnd = MP4Fixture.headerLength + MP4Fixture.sidxLength(count: 1, version: 1)
        #expect(index.fragments == [.init(offset: sidxEnd + 16, size: 640, duration: 0.5)])
    }

    @Test func truncatedIndexReportsHowMuchIsNeeded() throws {
        let data = MP4Fixture.indexed(fragments: [(1, 1), (2, 1)], timescale: 1)
        let cut = data.prefix(MP4Fixture.headerLength + 20)
        #expect(throws: MP4SegmentIndex.Failure.truncated(needed: data.count)) {
            try MP4SegmentIndex.parse(cut)
        }
    }

    @Test func dataEndingBeforeAnyIndexIsTruncated() {
        let onlyHeader = MP4Fixture.indexed(fragments: [(1, 1)], timescale: 1).prefix(MP4Fixture.headerLength)
        #expect(throws: MP4SegmentIndex.Failure.truncated(needed: MP4Fixture.headerLength + 8)) {
            try MP4SegmentIndex.parse(onlyHeader)
        }
    }

    @Test func mediaWithoutAnIndexIsRejected() {
        var data = MP4Fixture.box("ftyp", payload: Data(count: 8))
        data += MP4Fixture.box("moov", payload: Data(count: 8))
        data += MP4Fixture.box("mdat", payload: Data(count: 8))
        #expect(throws: MP4SegmentIndex.Failure.noIndex) { try MP4SegmentIndex.parse(data) }
    }

    @Test func garbageIsRejected() {
        #expect(throws: MP4SegmentIndex.Failure.noIndex) { try MP4SegmentIndex.parse(Data(count: 64)) }
        var emptySidx = MP4Fixture.box("ftyp", payload: Data())
        emptySidx += MP4Fixture.box("sidx", payload: Data(count: 4))
        #expect(throws: MP4SegmentIndex.Failure.noIndex) { try MP4SegmentIndex.parse(emptySidx) }
    }

    @Test func zeroFragmentsOrTimescaleIsRejected() {
        #expect(throws: MP4SegmentIndex.Failure.noIndex) {
            try MP4SegmentIndex.parse(MP4Fixture.indexed(fragments: [], timescale: 1))
        }
        #expect(throws: MP4SegmentIndex.Failure.noIndex) {
            try MP4SegmentIndex.parse(MP4Fixture.indexed(fragments: [(1, 1)], timescale: 0))
        }
    }

    @Test func largesizeBoxHeadersAreWalked() throws {
        var data = MP4Fixture.box("ftyp", payload: Data(count: 8), largesize: true)
        data += MP4Fixture.indexed(fragments: [(10, 5)], timescale: 10).dropFirst(MP4Fixture.headerLength)
        let index = try MP4SegmentIndex.parse(data)
        #expect(index.initLength == 24)
        #expect(index.fragments.first?.duration == 0.5)
        #expect(throws: MP4SegmentIndex.Failure.truncated(needed: 16)) {
            try MP4SegmentIndex.parse(data.prefix(12))
        }
    }
}
