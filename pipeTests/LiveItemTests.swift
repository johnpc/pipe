import Testing
import Foundation
@testable import pipe

/// The live flag travels from the stream payload into the queue and keeps live
/// items out of watch history.
struct LiveItemTests {
    private func stream(live: Bool?) -> StreamResponse {
        StreamResponse(title: "t", description: nil, uploader: "u", uploaderUrl: nil, duration: 0, hls: "https://m/x.m3u8",
                       audioStreams: [], videoStreams: [], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil,
                       subtitles: nil, livestream: live)
    }

    @Test func resolveCarriesTheLiveFlag() {
        #expect(Playback.resolve(stream(live: true), videoId: "a").isLive)
        #expect(!Playback.resolve(stream(live: nil), videoId: "a").isLive)
    }

    @Test func resolverAppliesTheLiveFlagToTheItem() {
        let item = QueueItem(videoId: "a", title: "", artist: "", thumbnail: "", url: "", audioUrl: "", duration: 0, uploadedDate: nil)
        #expect(PipedStreamResolver.apply(stream(live: true), to: item, language: "en")?.isLive == true)
        #expect(PipedStreamResolver.apply(stream(live: false), to: item, language: "en")?.isLive == false)
    }

    @Test func pendingItemFromALiveRowIsLive() {
        let live = RelatedStream(url: "/watch?v=l", title: "L", thumbnail: "", duration: -1, uploaderName: "U", uploadedDate: nil, uploaded: -1)
        let vod = RelatedStream(url: "/watch?v=v", title: "V", thumbnail: "", duration: 90, uploaderName: "U", uploadedDate: "1 day ago", uploaded: 1)
        #expect(QueueItem(pending: live).isLive)
        #expect(!QueueItem(pending: vod).isLive)
    }

    @Test func liveFlagRoundTripsAndDefaultsToFalse() throws {
        var item = QueueItem(videoId: "a", title: "t", artist: "ar", thumbnail: "th", url: "u", audioUrl: "au", duration: 0, uploadedDate: nil)
        item.isLive = true
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(QueueItem.self, from: data).isLive)
        let legacy = Data(#"{"videoId":"a","title":"t","artist":"ar","thumbnail":"th","url":"u","audioUrl":"au","duration":0}"#.utf8)
        #expect(try JSONDecoder().decode(QueueItem.self, from: legacy).isLive == false)
    }

    @Test func recentsPolicySkipsLiveItems() {
        var live = QueueItem(videoId: "l", title: "", artist: "", thumbnail: "", url: "", audioUrl: "", duration: 0, uploadedDate: nil)
        live.isLive = true
        let vod = QueueItem(videoId: "v", title: "", artist: "", thumbnail: "", url: "", audioUrl: "", duration: 90, uploadedDate: nil)
        #expect(!RecentsPolicy.records(live))
        #expect(RecentsPolicy.records(vod))
        #expect(!RecentsPolicy.recordsProgress(for: "l", in: [live, vod]))
        #expect(RecentsPolicy.recordsProgress(for: "v", in: [live, vod]))
        #expect(RecentsPolicy.recordsProgress(for: "unknown", in: [live]))
    }
}
