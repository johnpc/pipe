import Testing
import Foundation
@testable import pipe

struct StreamURLHelperTests {

    // MARK: - formatDuration

    @Test func formatDurationUnderOneHour() {
        #expect(formatDuration(0) == "0m0s")
        #expect(formatDuration(65) == "1m5s")
        #expect(formatDuration(599) == "9m59s")
    }

    @Test func formatDurationOverOneHour() {
        #expect(formatDuration(3600) == "1h0m")
        #expect(formatDuration(3725) == "1h2m")
        #expect(formatDuration(7384) == "2h3m")
    }

    // MARK: - formatTime

    @Test func formatTimeNormal() {
        #expect(formatTime(0) == "0:00")
        #expect(formatTime(5) == "0:05")
        #expect(formatTime(65) == "1:05")
        #expect(formatTime(3661) == "61:01")
    }

    @Test func formatTimeInvalidInputs() {
        #expect(formatTime(.nan) == "0:00")
        #expect(formatTime(-10) == "0:00")
        #expect(formatTime(.infinity) == "0:00")
    }

    // MARK: - getStreamUrl

    @Test func getStreamUrlRewritesProxyHost() {
        let stream = makeStream(videoStreams: [
            VideoStream(url: "https://pipedproxy.jpc.io/videoplayback?host=rr3---abc.googlevideo.com&itag=18", quality: "360p", mimeType: "video/mp4", videoOnly: false)
        ])
        let result = getStreamUrl(stream)
        #expect(result.hasPrefix("https://rr3---abc.googlevideo.com/"))
        #expect(!result.contains("host="))
        #expect(!result.contains("pipedproxy"))
    }

    @Test func getStreamUrlPicksNonVideoOnlyMp4() {
        let stream = makeStream(videoStreams: [
            VideoStream(url: "https://x/vo.mp4", quality: "1080p", mimeType: "video/mp4", videoOnly: true),
            VideoStream(url: "https://x/full.mp4", quality: "360p", mimeType: "video/mp4", videoOnly: false)
        ])
        #expect(getStreamUrl(stream) == "https://x/full.mp4")
    }

    @Test func getStreamUrlEmptyWhenNoMp4() {
        let stream = makeStream(videoStreams: [
            VideoStream(url: "https://x/a.webm", quality: "360p", mimeType: "video/webm", videoOnly: false)
        ])
        #expect(getStreamUrl(stream) == "")
    }

    // MARK: - formatUploadDate

    @Test func formatUploadDateParsesISO8601() {
        // A far-past date should produce a relative string, not echo the input.
        let result = formatUploadDate("2020-01-01T00:00:00.000Z")
        #expect(result != "2020-01-01T00:00:00.000Z")
        #expect(!result.isEmpty)
    }

    @Test func formatUploadDatePassesThroughHumanReadable() {
        #expect(formatUploadDate("3 weeks ago") == "3 weeks ago")
    }

    // MARK: - htmlToAttributedString

    @Test func htmlToAttributedStringParsesMarkup() {
        let result = htmlToAttributedString("<b>Hello</b>")
        #expect(String(result.characters).contains("Hello"))
    }

    // MARK: - Helpers

    private func makeStream(videoStreams: [VideoStream]) -> StreamResponse {
        StreamResponse(title: "t", description: nil, uploader: "u", uploaderUrl: nil, duration: 100, hls: nil, audioStreams: [], videoStreams: videoStreams, thumbnailUrl: "", uploadDate: nil)
    }
}
