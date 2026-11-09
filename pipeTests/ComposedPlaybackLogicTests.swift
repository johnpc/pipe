import Testing
import Foundation
@testable import pipe

/// When video mode pairs a video-only track with the chosen audio track, and
/// how that pair is carried on the queue item and resolved stream.
struct ComposedPlaybackLogicTests {
    private func item(videoOnly: String = "https://x/v.mp4", audio: String = "https://x/a.m4a") -> QueueItem {
        QueueItem(videoId: "v", title: "T", artist: "A", thumbnail: "", url: "https://x/muxed.mp4",
                  audioUrl: audio, videoOnlyUrl: videoOnly, duration: 10, uploadedDate: nil)
    }

    @Test func pairsInVideoModeWhenBothTracksExist() {
        let pair = ComposedPlaybackLogic.pair(for: item(), videoMode: true, isLocal: false)
        #expect(pair?.video.absoluteString == "https://x/v.mp4")
        #expect(pair?.audio.absoluteString == "https://x/a.m4a")
    }

    @Test func noPairInAudioMode() {
        #expect(ComposedPlaybackLogic.pair(for: item(), videoMode: false, isLocal: false) == nil)
    }

    @Test func noPairForDownloadedItem() {
        #expect(ComposedPlaybackLogic.pair(for: item(), videoMode: true, isLocal: true) == nil)
    }

    @Test func noPairWithoutVideoOnlyOrAudioTrack() {
        #expect(ComposedPlaybackLogic.pair(for: item(videoOnly: ""), videoMode: true, isLocal: false) == nil)
        #expect(ComposedPlaybackLogic.pair(for: item(audio: ""), videoMode: true, isLocal: false) == nil)
        #expect(ComposedPlaybackLogic.pair(for: item(videoOnly: "not a url at all ^"), videoMode: true, isLocal: false) == nil)
    }

    // MARK: - Wire / disk formats

    @Test func queueItemRoundTripsVideoOnlyURL() throws {
        let decoded = try JSONDecoder().decode(QueueItem.self, from: JSONEncoder().encode(item()))
        #expect(decoded.videoOnlyUrl == "https://x/v.mp4")
    }

    @Test func legacyQueueItemDecodesWithoutVideoOnlyURL() throws {
        let json = #"{"videoId":"v","title":"T","artist":"A","thumbnail":"","url":"u","audioUrl":"","duration":1}"#
        let decoded = try JSONDecoder().decode(QueueItem.self, from: Data(json.utf8))
        #expect(decoded.videoOnlyUrl == "")
    }

    @Test func resolveCarriesVideoOnlyURL() {
        let stream = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 1, hls: nil,
                                    audioStreams: [], videoStreams: [
                                        VideoStream(url: "https://x/muxed", quality: "360p", mimeType: "video/mp4", videoOnly: false),
                                        VideoStream(url: "https://x/v720", quality: "720p", mimeType: "video/mp4", videoOnly: true),
                                    ], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
        let resolved = Playback.resolve(stream, videoId: "v")
        #expect(resolved.url == "https://x/muxed")
        #expect(resolved.videoOnlyURL == "https://x/v720")
    }

    @MainActor @Test func applyCarriesVideoOnlyURLOntoQueueItems() {
        let player = isolatedPlayer()
        var resolved = ResolvedStream(videoId: "v", url: "bad://u", audioUrl: "", title: "t", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        resolved.videoOnlyURL = "https://x/v720"
        Playback.apply(resolved, action: .queue, to: player)
        let next = ResolvedStream(videoId: "v2", url: "bad://u", audioUrl: "", videoOnlyURL: "https://x/v2", title: "t", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        Playback.apply(next, action: .playNext, to: player)
        #expect(player.queue.map(\.videoOnlyUrl) == ["https://x/v720", "https://x/v2"])
    }
}
