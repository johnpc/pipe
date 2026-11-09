import Foundation

/// Pure choice of the video-only track to pair with a separately chosen audio
/// track in video mode. YouTube's only muxed MP4 is 360p with one fixed audio
/// track; the adaptive video-only tracks go up to 1080p and let the audio
/// language be chosen independently.
enum VideoTrackLogic {
    /// Resolution ceiling for the phone's screen; above it only costs data.
    static let maxHeight = 1080

    /// YouTube itags whose MP4 payload is AV1. Older iPhones can't decode AV1
    /// in hardware, so those tracks are passed over when an H.264 one exists.
    static let av1Itags: Set<Int> = [394, 395, 396, 397, 398, 399, 400, 401, 402, 571]

    /// The `itag` query parameter of a googlevideo URL, when present.
    static func itag(of url: String) -> Int? {
        URLComponents(string: url)?.queryItems?.first { $0.name == "itag" }?.value.flatMap(Int.init)
    }

    static func isAV1(_ stream: VideoStream) -> Bool {
        itag(of: stream.url).map(av1Itags.contains) ?? false
    }

    /// Highest video-only MP4 at or below `maxHeight`, preferring non-AV1
    /// codecs. Falls back to the lowest available when every track is above
    /// the cap. Empty when the response has no video-only MP4 track at all.
    static func bestVideoOnlyURL(from streams: [VideoStream], maxHeight: Int = maxHeight) -> String {
        let videoOnly = streams.filter { $0.mimeType.contains("mp4") && $0.videoOnly == true }
        let h264 = videoOnly.filter { !isAV1($0) }
        let pool = h264.isEmpty ? videoOnly : h264
        guard !pool.isEmpty else { return "" }
        let sorted = pool.sorted { height($0) > height($1) }
        let atOrBelow = sorted.first { height($0) <= maxHeight }
        return (atOrBelow ?? sorted.last)?.url ?? ""
    }

    private static func height(_ stream: VideoStream) -> Int {
        CastQualityLogic.height(from: stream.quality) ?? 0
    }
}
