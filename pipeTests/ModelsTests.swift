import Testing
import Foundation
@testable import pipe

struct ModelsTests {

    // MARK: - SearchItem computed properties

    @Test func searchItemVideoIdAndChannelId() {
        let video = SearchItem(url: "/watch?v=abc123", type: "stream", title: "T", thumbnail: "th", uploaderName: "U", uploaderUrl: nil, duration: 10, name: nil, uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(video.videoId == "abc123")
        #expect(video.isChannel == false)

        let chan = SearchItem(url: "/channel/UC1", type: "channel", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: "ChanName", uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(chan.channelId == "UC1")
        #expect(chan.isChannel == true)
    }

    @Test func searchItemDisplayFallbacks() {
        let withName = SearchItem(url: "/channel/c", type: "channel", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: "TheName", uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(withName.displayTitle == "TheName")

        let withTitle = SearchItem(url: "/watch?v=v", type: "stream", title: "TheTitle", thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(withTitle.displayTitle == "TheTitle")

        let neither = SearchItem(url: "/watch?v=v", type: "stream", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(neither.displayTitle == "Unknown")
        #expect(neither.displayUploader == "")
        #expect(neither.displayThumbnail == "")
    }

    @Test func searchItemIdIsURL() {
        let item = SearchItem(url: "/watch?v=x", type: "stream", title: nil, thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil)
        #expect(item.id == "/watch?v=x")
    }

    // MARK: - RelatedStream

    @Test func relatedStreamVideoIdAndId() {
        let s = RelatedStream(url: "/watch?v=zzz", title: "T", thumbnail: "th", duration: 30, uploaderName: "U", uploadedDate: nil, uploaded: 999)
        #expect(s.videoId == "zzz")
        #expect(s.id == "/watch?v=zzz")
    }

    // MARK: - FollowedChannel Codable

    @Test func followedChannelRoundTrips() throws {
        let original = FollowedChannel(id: "c1", name: "Name", thumbnail: "th")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FollowedChannel.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - RecentItem

    @Test func recentItemIdIsVideoId() {
        let item = RecentItem(videoId: "v1", title: "T", artist: "A", thumbnail: "", timestamp: 0, lastWatched: Date())
        #expect(item.id == "v1")
    }

    @Test func recentItemRoundTrips() throws {
        let item = RecentItem(videoId: "v1", title: "T", artist: "A", thumbnail: "th", timestamp: 12.5, lastWatched: Date(timeIntervalSince1970: 1000), duration: 100, uploadedDate: "2026")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(RecentItem.self, from: data)
        #expect(decoded == item)
    }

    // MARK: - QueueItem

    @Test func queueItemsHaveUniqueIds() {
        let a = QueueItem(videoId: "v", title: "t", artist: "a", thumbnail: "", url: "u", audioUrl: "", duration: 0, uploadedDate: nil)
        let b = QueueItem(videoId: "v", title: "t", artist: "a", thumbnail: "", url: "u", audioUrl: "", duration: 0, uploadedDate: nil)
        #expect(a.id != b.id)
    }

    @Test func queueItemPlaybackURLPrefersAudioWhenNotVideoMode() {
        let item = QueueItem(videoId: "v", title: "t", artist: "a", thumbnail: "", url: "video-url", audioUrl: "audio-url", duration: 0, uploadedDate: nil)
        #expect(item.playbackURL(videoMode: false) == "audio-url")
        #expect(item.playbackURL(videoMode: true) == "video-url")
    }

    @Test func queueItemPlaybackURLFallsBackToVideoWhenNoAudio() {
        let item = QueueItem(videoId: "v", title: "t", artist: "a", thumbnail: "", url: "video-url", audioUrl: "", duration: 0, uploadedDate: nil)
        #expect(item.playbackURL(videoMode: false) == "video-url")
        #expect(item.playbackURL(videoMode: true) == "video-url")
    }

    @Test func queueItemRoundTripsThroughCodable() throws {
        let item = QueueItem(videoId: "v", title: "T", artist: "A", thumbnail: "th", url: "u", audioUrl: "au", duration: 42, uploadedDate: "2026")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(QueueItem.self, from: data)
        // id is regenerated on decode; compare the persisted fields.
        #expect(decoded.videoId == item.videoId)
        #expect(decoded.url == item.url)
        #expect(decoded.audioUrl == item.audioUrl)
        #expect(decoded.duration == 42)
    }
}
