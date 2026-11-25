import Testing
import Foundation
@testable import pipe

struct FeedPublicationTests {
    private func video(_ id: String, channel: String, uploaded: Int64?) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(id)", title: id, thumbnail: "", duration: 600, uploaderName: channel, uploadedDate: nil, uploaded: uploaded)
    }
    private let day: Int64 = 86_400_000

    @Test func membersEarlyVideoAppearingLateIsALatePublication() {
        // Known: Andrei's newest public video is from day 10. A video dated day 7
        // shows up for the first time → it was members-only until now.
        let known = [video("a10", channel: "Andrei", uploaded: 10 * day), video("a5", channel: "Andrei", uploaded: 5 * day)]
        let fresh = known + [video("a7", channel: "Andrei", uploaded: 7 * day)]
        #expect(FeedPublication.latePublications(fresh: fresh, known: known) == ["a7"])
    }

    @Test func genuinelyNewUploadIsNotLate() {
        let known = [video("a10", channel: "Andrei", uploaded: 10 * day)]
        let fresh = known + [video("a11", channel: "Andrei", uploaded: 11 * day), video("a10b", channel: "Andrei", uploaded: 10 * day)]
        #expect(FeedPublication.latePublications(fresh: fresh, known: known).isEmpty)
    }

    @Test func newlyFollowedChannelAndFirstLoadAreNotLate() {
        let known = [video("a10", channel: "Andrei", uploaded: 10 * day)]
        let fresh = known + [video("b1", channel: "Brand New", uploaded: 1 * day)]
        #expect(FeedPublication.latePublications(fresh: fresh, known: known).isEmpty)
        #expect(FeedPublication.latePublications(fresh: fresh, known: []).isEmpty)
    }

    @Test func liveAndUndatedRowsAreIgnored() {
        let known = [video("a10", channel: "Andrei", uploaded: 10 * day)]
        let fresh = known + [video("live", channel: "Andrei", uploaded: -1), video("nodate", channel: "Andrei", uploaded: nil)]
        #expect(FeedPublication.latePublications(fresh: fresh, known: known).isEmpty)
    }

    @Test func applyingMovesOnlyLaterReleaseDates() {
        let videos = [video("a7", channel: "Andrei", uploaded: 7 * day), video("a10", channel: "Andrei", uploaded: 10 * day)]
        let out = FeedPublication.applying(["a7": 12 * day, "a10": 1 * day], to: videos)
        #expect(out.map(\.uploaded) == [12 * day, 10 * day])
        #expect(out[0].title == "a7" && out[0].url == "/watch?v=a7")
    }

    @Test func storeRecordsOnceAndPrunes() {
        let defaults = UserDefaults(suiteName: "FeedPublicationTests.\(UUID())")!
        let store = PublicReleaseStore(defaults: defaults)
        store.record(["a7"], at: Date(timeIntervalSince1970: 1000))
        store.record(["a7", "b2"], at: Date(timeIntervalSince1970: 2000))
        #expect(store.dates == ["a7": 1_000_000, "b2": 2_000_000])
        store.prune(keeping: ["b2"])
        #expect(store.dates == ["b2": 2_000_000])
        store.record([], at: Date())
        #expect(store.dates.count == 1)
    }

    @Test func arrangePutsLatePublicationOnTopAndPersists() {
        let defaults = UserDefaults(suiteName: "FeedPublicationTests.\(UUID())")!
        let store = PublicReleaseStore(defaults: defaults)
        let known = [video("a10", channel: "Andrei", uploaded: 10 * day), video("c9", channel: "Casey", uploaded: 9 * day)]
        let fresh = known + [video("a7", channel: "Andrei", uploaded: 7 * day)]
        let now = Date(timeIntervalSince1970: Double(12 * day) / 1000)
        let out = FeedLoader.arrange(fresh, known: known, releases: store, now: now)
        #expect(out.map(\.videoId) == ["a7", "a10", "c9"])
        // Next refresh: the stamp survives, so it stays on top even though the
        // adjusted rows are now what is "known"; a dropped video is forgotten.
        let again = FeedLoader.arrange([fresh[0], fresh[2]], known: out, releases: store, now: now.addingTimeInterval(60))
        #expect(again.map(\.videoId) == ["a7", "a10"])
        #expect(store.dates.keys.sorted() == ["a7"])
    }
}
