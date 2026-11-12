import Foundation

/// Text of the HLS playlists that present a video-only stream and an audio
/// stream as one program: a master playlist naming the two renditions, and a
/// media playlist per stream whose segments are byte ranges of the original
/// file (from its `MP4SegmentIndex`). AVPlayer fetches the ranges from the
/// stream URL itself; only the playlists come from the app, via a custom
/// scheme served by `HLSPlaylistLoader`.
enum HLSPlaylist {
    static let scheme = "pipe-hls"
    static let master = "master"
    static let video = "video"
    static let audio = "audio"

    /// `pipe-hls://<name>/index.m3u8`, the URL a playlist is served under.
    static func url(_ name: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = name
        parts.path = "/index.m3u8"
        return parts.url
    }

    /// The playlist name a request URL refers to, when it uses our scheme.
    static func name(for url: URL?) -> String? {
        guard let url, url.scheme == scheme else { return nil }
        return url.host
    }

    /// One variant (the video) with the audio as its selected rendition. The
    /// bandwidth is nominal: there's nothing to switch between.
    static func masterPlaylist(bandwidth: Int = 6_000_000) -> String {
        let audioURI = url(audio)?.absoluteString ?? ""
        let videoURI = url(video)?.absoluteString ?? ""
        return """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Audio",DEFAULT=YES,AUTOSELECT=YES,URI="\(audioURI)"
        #EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),AUDIO="audio"
        \(videoURI)

        """
    }

    /// A VOD media playlist: the init section as the map, each fragment as a
    /// byte-range segment of `source`.
    static func mediaPlaylist(source: URL, index: MP4SegmentIndex) -> String {
        let longest = index.fragments.map(\.duration).max() ?? 1
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-TARGETDURATION:\(Int(longest.rounded(.up)))",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-MAP:URI=\"\(source.absoluteString)\",BYTERANGE=\"\(index.initLength)@0\"",
        ]
        for fragment in index.fragments {
            lines.append("#EXTINF:\(String(format: "%.5f", fragment.duration)),")
            lines.append("#EXT-X-BYTERANGE:\(fragment.size)@\(fragment.offset)")
            lines.append(source.absoluteString)
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }
}
