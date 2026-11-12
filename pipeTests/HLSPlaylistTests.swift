import Testing
import Foundation
@testable import pipe

struct HLSPlaylistTests {
    private let source = URL(string: "https://cdn.example/videoplayback?itag=137&sig=x")!
    private let index = MP4SegmentIndex(initLength: 743, fragments: [
        .init(offset: 13111, size: 598108, duration: 5.0),
        .init(offset: 611219, size: 420000, duration: 2.5),
    ])

    @Test func playlistURLsRoundTrip() throws {
        let url = try #require(HLSPlaylist.url(HLSPlaylist.video))
        #expect(url.absoluteString == "pipe-hls://video/index.m3u8")
        #expect(HLSPlaylist.name(for: url) == "video")
        #expect(HLSPlaylist.name(for: URL(string: "https://video/index.m3u8")) == nil)
        #expect(HLSPlaylist.name(for: nil) == nil)
    }

    @Test func masterNamesTheAudioRenditionAndVideoVariant() {
        let text = HLSPlaylist.masterPlaylist(bandwidth: 1234)
        #expect(text.hasPrefix("#EXTM3U\n"))
        #expect(text.contains("#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Audio\",DEFAULT=YES,AUTOSELECT=YES,URI=\"pipe-hls://audio/index.m3u8\""))
        #expect(text.contains("#EXT-X-STREAM-INF:BANDWIDTH=1234,AUDIO=\"audio\"\npipe-hls://video/index.m3u8\n"))
    }

    @Test func mediaPlaylistMapsTheInitSectionAndEachFragmentAsAByteRange() {
        let lines = HLSPlaylist.mediaPlaylist(source: source, index: index).split(separator: "\n").map(String.init)
        #expect(lines.first == "#EXTM3U")
        #expect(lines.contains("#EXT-X-TARGETDURATION:5"))
        #expect(lines.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(lines.contains("#EXT-X-MAP:URI=\"\(source.absoluteString)\",BYTERANGE=\"743@0\""))
        let first = lines.firstIndex(of: "#EXTINF:5.00000,") ?? -1
        #expect(first > 0)
        #expect(lines[first + 1] == "#EXT-X-BYTERANGE:598108@13111")
        #expect(lines[first + 2] == source.absoluteString)
        #expect(lines.contains("#EXTINF:2.50000,"))
        #expect(lines.contains("#EXT-X-BYTERANGE:420000@611219"))
        #expect(lines.last == "#EXT-X-ENDLIST")
    }

    @Test func emptyIndexStillYieldsAValidPlaylist() {
        let text = HLSPlaylist.mediaPlaylist(source: source, index: MP4SegmentIndex(initLength: 10, fragments: []))
        #expect(text.contains("#EXT-X-TARGETDURATION:1"))
        #expect(!text.contains("#EXTINF"))
    }
}
