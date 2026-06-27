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

    @Test func sortLabels() {
        #expect(FeedSort.newest.label == "Newest")
        #expect(FeedSort.channel.label == "By Channel")
        #expect(FeedSort.allCases.count == 2)
    }
}
