import Testing
import Foundation
@testable import pipe

struct QueueItemPendingTests {

    @Test func pendingHasNoURLsAndIsStale() {
        let q = QueueItem.pending(videoId: "abc", title: "T", artist: "A", thumbnail: "th", duration: 90, uploadedDate: "2 days ago")
        #expect(q.videoId == "abc")
        #expect(q.title == "T")
        #expect(q.artist == "A")
        #expect(q.thumbnail == "th")
        #expect(q.duration == 90)
        #expect(q.uploadedDate == "2 days ago")
        #expect(q.url.isEmpty && q.audioUrl.isEmpty && q.castUrl.isEmpty && q.videoOnlyUrl.isEmpty)
        #expect(q.resolvedAt == nil)
        // Stale → playItem re-resolves the URL before first play if the
        // background resolution hasn't landed yet.
        #expect(StreamFreshness.needsRefresh(resolvedAt: q.resolvedAt, now: Date(), isLocal: false))
    }

    @Test func fromRelatedStream() {
        let v = RelatedStream(url: "/watch?v=abc", title: "T", thumbnail: "th", duration: 90, uploaderName: "Up", uploadedDate: "2 days ago", uploaded: nil)
        let q = QueueItem(pending: v)
        #expect(q.videoId == "abc")
        #expect(q.title == "T")
        #expect(q.artist == "Up")
        #expect(q.thumbnail == "th")
        #expect(q.duration == 90)
        #expect(q.uploadedDate == "2 days ago")
        #expect(q.resolvedAt == nil)
    }

    @Test func fromRelatedStreamWithoutUploaderHasEmptyArtist() {
        let v = RelatedStream(url: "/watch?v=abc", title: "T", thumbnail: "th", duration: 0, uploaderName: nil, uploadedDate: nil, uploaded: nil)
        #expect(QueueItem(pending: v).artist == "")
    }

    @Test func fromSearchItem() {
        let item = SearchItem(url: "/watch?v=s1", type: "stream", title: "Song", thumbnail: "th", uploaderName: "Artist", uploaderUrl: nil, duration: 120, name: nil, uploadedDate: "1 week ago", verified: nil, subscribers: nil, videos: nil)
        let q = QueueItem(pending: item)
        #expect(q.videoId == "s1")
        #expect(q.title == "Song")
        #expect(q.artist == "Artist")
        #expect(q.thumbnail == "th")
        #expect(q.duration == 120)
        #expect(q.uploadedDate == "1 week ago")
        #expect(q.resolvedAt == nil)
    }

    @Test func fromSearchItemWithMissingFieldsUsesDefaults() {
        let item = SearchItem(url: "/watch?v=s2", type: "stream", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil, videos: nil)
        let q = QueueItem(pending: item)
        #expect(q.title == "Unknown")
        #expect(q.artist == "")
        #expect(q.thumbnail == "")
        #expect(q.duration == 0)
    }

    @Test func fromRecentItem() {
        let item = RecentItem(videoId: "r1", title: "Watched", artist: "Someone", thumbnail: "th", timestamp: 30, lastWatched: Date(), duration: 600, uploadedDate: "yesterday")
        let q = QueueItem(pending: item)
        #expect(q.videoId == "r1")
        #expect(q.title == "Watched")
        #expect(q.artist == "Someone")
        #expect(q.thumbnail == "th")
        #expect(q.duration == 600)
        #expect(q.uploadedDate == "yesterday")
        #expect(q.resolvedAt == nil)
    }
}
