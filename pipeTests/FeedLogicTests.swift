import Testing
import Foundation
@testable import pipe

struct FeedLogicTests {

    private func s(_ id: String, uploader: String, uploaded: Int64) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(id)", title: id, thumbnail: "", duration: 0, uploaderName: uploader, uploadedDate: nil, uploaded: uploaded)
    }

    private let none: (RelatedStream) -> Bool = { _ in false }

    @Test func newestSortsByUploadDescending() {
        let vids = [s("a", uploader: "X", uploaded: 100), s("b", uploader: "Y", uploaded: 300), s("c", uploader: "Z", uploaded: 200)]
        let out = FeedLogic.arrange(vids, sort: .newest, hideWatched: false, isWatched: none)
        #expect(out.map(\.videoId) == ["b", "c", "a"])
    }

    @Test func channelSortGroupsByUploaderThenNewest() {
        let vids = [
            s("a1", uploader: "Beta", uploaded: 100),
            s("b1", uploader: "Alpha", uploaded: 100),
            s("b2", uploader: "Alpha", uploaded: 300),
        ]
        let out = FeedLogic.arrange(vids, sort: .channel, hideWatched: false, isWatched: none)
        // Alpha group first (newest within), then Beta.
        #expect(out.map(\.videoId) == ["b2", "b1", "a1"])
    }

    @Test func hideWatchedFiltersOutCompleted() {
        let vids = [s("a", uploader: "X", uploaded: 100), s("b", uploader: "Y", uploaded: 200)]
        let out = FeedLogic.arrange(vids, sort: .newest, hideWatched: true) { $0.videoId == "b" }
        #expect(out.map(\.videoId) == ["a"])
    }

    @Test func hideWatchedFalseKeepsAll() {
        let vids = [s("a", uploader: "X", uploaded: 100), s("b", uploader: "Y", uploaded: 200)]
        let out = FeedLogic.arrange(vids, sort: .newest, hideWatched: false) { _ in true }
        #expect(out.count == 2)
    }

    @Test func sectionsSplitLiveUpcomingAndUploads() {
        // Fixed clock: Wed 2026-11-25 15:00Z. Live rows have uploaded -1 and no
        // date; upcoming ones a UTC start string; the rest are uploads.
        let now = Date(timeIntervalSince1970: 1_795_618_800)
        let live = RelatedStream(url: "/watch?v=live", title: "live", thumbnail: "", duration: -1, uploaderName: "X", uploadedDate: nil, uploaded: -1)
        let later = RelatedStream(url: "/watch?v=later", title: "later", thumbnail: "", duration: -1, uploaderName: "X", uploadedDate: "2026-11-26 23:00", uploaded: 1_795_734_000_000)
        let soon = RelatedStream(url: "/watch?v=soon", title: "soon", thumbnail: "", duration: -1, uploaderName: "Y", uploadedDate: "2026-11-25 20:00", uploaded: 1_795_636_800_000)
        let vids = [s("a", uploader: "X", uploaded: 100), later, live, s("b", uploader: "Y", uploaded: 300), soon]
        let out = FeedLogic.sections(vids, sort: .newest, hideWatched: true, now: now) { $0.videoId == "a" }
        #expect(out.live.map(\.videoId) == ["live"])
        #expect(out.upcoming.map(\.videoId) == ["soon", "later"])
        #expect(out.videos.map(\.videoId) == ["b"])
        #expect(!out.isEmpty)
        #expect(FeedLogic.sections([], sort: .newest, hideWatched: false, now: now) { _ in false }.isEmpty)
    }

    @Test func sortLabels() {
        #expect(FeedSort.newest.label == "Newest")
        #expect(FeedSort.channel.label == "By Channel")
        #expect(FeedSort.allCases.count == 2)
    }
}
