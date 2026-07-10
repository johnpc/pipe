import Testing
import Foundation
@testable import pipe

struct CastLogicTests {

    // MARK: - Video URL is always used (never audio-only)

    @Test func mediaFromResolvedUsesVideoUrlNotAudio() {
        let resolved = ResolvedStream(videoId: "v", url: "https://x/video.mp4", audioUrl: "https://x/audio.m4a", title: "T", artist: "A", thumbnail: "th", duration: 10, uploadedDate: nil)
        let media = CastLogic.media(from: resolved)
        #expect(media.url == "https://x/video.mp4")
        #expect(media.contentType == "video/mp4")
        #expect(media.title == "T")
        #expect(media.artist == "A")
        #expect(media.thumbnail == "th")
        #expect(media.startTime == 0)
    }

    @Test func mediaFromQueueItemUsesVideoUrl() {
        let item = QueueItem(videoId: "v", title: "Title", artist: "Chan", thumbnail: "th", url: "https://x/v.mp4", audioUrl: "https://x/a.m4a", duration: 30, uploadedDate: nil)
        let media = CastLogic.media(from: item, startTime: 12)
        #expect(media.url == "https://x/v.mp4")
        #expect(media.startTime == 12)
        #expect(media.contentType == "video/mp4")
    }

    // MARK: - Start time handling

    @Test func startTimeIsPassedThrough() {
        let resolved = ResolvedStream(videoId: "v", url: "u", audioUrl: "", title: "t", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        #expect(CastLogic.media(from: resolved, startTime: 42.5).startTime == 42.5)
    }

    @Test func negativeStartTimeClampsToZero() {
        let media = CastLogic.media(url: "u", title: "t", artist: "a", thumbnail: "", startTime: -5)
        #expect(media.startTime == 0)
    }

    // MARK: - A proxy-rewritten URL is preserved verbatim

    @Test func rewrittenUrlIsPreserved() {
        let rewritten = "https://rr5.googlevideo.com/videoplayback?expire=123"
        let resolved = ResolvedStream(videoId: "v", url: rewritten, audioUrl: "", title: "t", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        #expect(CastLogic.media(from: resolved).url == rewritten)
    }

    // MARK: - Castability

    @Test func castableRequiresNonEmptyUrl() {
        let ok = CastLogic.media(url: "https://x/v.mp4", title: "t", artist: "a", thumbnail: "", startTime: 0)
        let empty = CastLogic.media(url: "", title: "t", artist: "a", thumbnail: "", startTime: 0)
        #expect(CastLogic.isCastable(ok) == true)
        #expect(CastLogic.isCastable(empty) == false)
    }
}
