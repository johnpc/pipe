import Testing
import Foundation
@testable import pipe

/// Fetching a stream's head and growing the fetch when the index runs past it.
/// Serialized: the tests share `RangeServingURLProtocol`'s static state.
@Suite(.serialized)
struct MP4SegmentIndexLoaderTests {
    private let url = URL(string: "https://cdn.example/videoplayback?itag=140")!
    private let full = MP4Fixture.indexed(fragments: [(100, 1), (200, 1)], timescale: 1)

    @Test func loadsTheIndexFromARangeRequest() async throws {
        let session = RangeServingURLProtocol.makeSession(serving: full)
        let index = try await MP4SegmentIndexLoader.load(url, session: session)
        #expect(index.fragments.count == 2)
        #expect(RangeServingURLProtocol.ranges == ["bytes=0-\(MP4SegmentIndexLoader.initialBytes - 1)"])
    }

    @Test func growsTheFetchWhenTheIndexIsCutOff() async throws {
        let session = RangeServingURLProtocol.makeSession(serving: full, cutFirst: full.count - 4)
        let index = try await MP4SegmentIndexLoader.load(url, session: session)
        #expect(index.fragments.count == 2)
        #expect(RangeServingURLProtocol.ranges.count == 2)
        #expect(RangeServingURLProtocol.ranges.last == "bytes=0-\(full.count - 1)")
    }

    @Test func givesUpWhenTheServerCannotSendMore() async {
        let session = RangeServingURLProtocol.makeSession(serving: full.prefix(full.count - 4))
        await #expect(throws: MP4SegmentIndex.Failure.noIndex) {
            _ = try await MP4SegmentIndexLoader.load(url, session: session)
        }
        #expect(RangeServingURLProtocol.ranges.count == 2)
    }

    @Test func rejectsAnErrorStatus() async {
        let session = RangeServingURLProtocol.makeSession(serving: Data(), status: 403)
        await #expect(throws: URLError.self) {
            _ = try await MP4SegmentIndexLoader.load(url, session: session)
        }
    }
}
