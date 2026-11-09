import Testing
import Foundation
@testable import pipe

/// Choice of the video-only track paired with the chosen audio track in video
/// mode: highest H.264 MP4 at or below 1080p, AV1 only as a last resort.
struct VideoTrackLogicTests {
    private func stream(_ quality: String, itag: Int?, mime: String = "video/mp4", videoOnly: Bool? = true) -> VideoStream {
        let url = itag.map { "https://x/videoplayback?itag=\($0)&q=\(quality)" } ?? "https://x/\(quality)"
        return VideoStream(url: url, quality: quality, mimeType: mime, videoOnly: videoOnly)
    }

    @Test func parsesItagFromURL() {
        #expect(VideoTrackLogic.itag(of: "https://x/videoplayback?expire=1&itag=137&ip=2") == 137)
        #expect(VideoTrackLogic.itag(of: "https://x/videoplayback?expire=1") == nil)
        #expect(VideoTrackLogic.itag(of: "not a url") == nil)
    }

    @Test func prefersHighestH264AtOrBelowCap() {
        let streams = [stream("360p", itag: 18, videoOnly: false), stream("1080p", itag: 137), stream("1080p", itag: 399),
                       stream("720p", itag: 136), stream("1080p", itag: 303, mime: "video/webm")]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: streams).contains("itag=137"))
    }

    @Test func honorsTheHeightCap() {
        let streams = [stream("1080p", itag: 137), stream("720p", itag: 136), stream("480p", itag: 135)]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: streams, maxHeight: 720).contains("itag=136"))
    }

    @Test func fallsBackToLowestWhenAllAboveCap() {
        let streams = [stream("1080p", itag: 137), stream("1440p", itag: 264)]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: streams, maxHeight: 480).contains("itag=137"))
    }

    @Test func skipsAV1OnlyWhenAnH264TrackExists() {
        let onlyAV1 = [stream("1080p", itag: 399), stream("720p", itag: 398)]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: onlyAV1).contains("itag=399"))
        #expect(VideoTrackLogic.isAV1(stream("720p", itag: 398)))
        #expect(!VideoTrackLogic.isAV1(stream("720p", itag: 136)))
        #expect(!VideoTrackLogic.isAV1(stream("720p", itag: nil)))
    }

    @Test func unlabeledStreamsAreAccepted() {
        let streams = [stream("720p", itag: nil), stream("480p", itag: nil)]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: streams) == "https://x/720p")
    }

    @Test func emptyWithoutVideoOnlyMP4() {
        let streams = [stream("360p", itag: 18, videoOnly: false), stream("1080p", itag: 303, mime: "video/webm")]
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: streams) == "")
        #expect(VideoTrackLogic.bestVideoOnlyURL(from: []) == "")
    }

    @Test func helperResolvesFromStreamResponse() {
        let response = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 1, hls: nil,
                                      audioStreams: [], videoStreams: [stream("720p", itag: 136)], thumbnailUrl: "",
                                      uploadDate: nil, chapters: nil, relatedStreams: nil)
        #expect(getVideoOnlyStreamUrl(response).contains("itag=136"))
    }
}
