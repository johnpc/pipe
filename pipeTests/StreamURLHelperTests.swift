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

    // MARK: - getAudioStreamUrl

    @Test func getAudioStreamUrlPicksHighestBitrateM4A() {
        let stream = makeStream(audioStreams: [
            AudioStream(url: "https://x/lo.m4a", bitrate: 64000, mimeType: "audio/mp4"),
            AudioStream(url: "https://x/hi.m4a", bitrate: 160000, mimeType: "audio/mp4")
        ])
        #expect(getAudioStreamUrl(stream) == "https://x/hi.m4a")
    }

    @Test func getAudioStreamUrlFallsBackToAnyAudioWhenNoMp4() {
        let stream = makeStream(audioStreams: [
            AudioStream(url: "https://x/a.webm", bitrate: 128000, mimeType: "audio/webm")
        ])
        #expect(getAudioStreamUrl(stream) == "https://x/a.webm")
    }

    @Test func getAudioStreamUrlEmptyWhenNoAudio() {
        #expect(getAudioStreamUrl(makeStream()) == "")
    }

    @Test func getAudioStreamUrlRewritesProxyHost() {
        let stream = makeStream(audioStreams: [
            AudioStream(url: "https://pipedproxy.jpc.io/audioplayback?host=rr5---xyz.googlevideo.com&itag=140", bitrate: 128000, mimeType: "audio/mp4")
        ])
        let result = getAudioStreamUrl(stream)
        #expect(result.hasPrefix("https://rr5---xyz.googlevideo.com/"))
        #expect(!result.contains("host="))
    }

    // MARK: - rewriteProxyHost

    @Test func rewriteProxyHostNoOpWithoutHostParam() {
        #expect(rewriteProxyHost("https://example.com/video.mp4?itag=18") == "https://example.com/video.mp4?itag=18")
    }

    @Test func rewriteProxyHostWorksForArbitraryInstance() {
        // Not tied to a hardcoded instance origin.
        let input = "https://proxy.other-instance.net/x?host=upstream.googlevideo.com&itag=18"
        let result = rewriteProxyHost(input)
        #expect(result.hasPrefix("https://upstream.googlevideo.com/"))
        #expect(!result.contains("host="))
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

    private func makeStream(videoStreams: [VideoStream] = [], audioStreams: [AudioStream] = []) -> StreamResponse {
        StreamResponse(title: "t", description: nil, uploader: "u", uploaderUrl: nil, duration: 100, hls: nil, audioStreams: audioStreams, videoStreams: videoStreams, thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
    }
}
