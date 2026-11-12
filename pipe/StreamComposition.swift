import AVFoundation

/// Decides whether an item plays as a composed pair of video-only + audio
/// tracks. Pure so the decision is tested without AVFoundation: only in video
/// mode, only for streamed (not downloaded) items, and only when both tracks
/// were resolved. Everything else keeps the single-stream path.
enum ComposedPlaybackLogic {
    struct Pair: Equatable {
        let video: URL
        let audio: URL
    }

    static func pair(for item: QueueItem, videoMode: Bool, isLocal: Bool) -> Pair? {
        guard videoMode, !isLocal, !item.videoOnlyUrl.isEmpty, !item.audioUrl.isEmpty,
              let video = URL(string: item.videoOnlyUrl), let audio = URL(string: item.audioUrl)
        else { return nil }
        return Pair(video: video, audio: audio)
    }
}

/// A playable video-only + audio pair, with the playlist server it depends on.
struct ComposedStream {
    let item: AVPlayerItem
    /// Must outlive the item: AVFoundation holds its loader delegate weakly.
    let loader: HLSPlaylistLoader
}

/// Plays a video-only track and a separate audio track in lockstep by
/// describing both to AVPlayer as an HLS presentation: each stream's own
/// segment index (its `sidx` box, a few hundred KB from the head of the file)
/// becomes a byte-range media playlist, so AVPlayer streams and seeks them
/// like any HLS program. Nothing is downloaded up front beyond the two indexes.
enum StreamComposition {
    enum Failure: Error {
        case badPlaylistURL
    }

    static func build(video: URL, audio: URL) async throws -> ComposedStream {
        async let videoIndex = MP4SegmentIndexLoader.load(video)
        async let audioIndex = MP4SegmentIndexLoader.load(audio)
        let (v, a) = try await (videoIndex, audioIndex)
        let loader = HLSPlaylistLoader(playlists: [
            HLSPlaylist.master: HLSPlaylist.masterPlaylist(),
            HLSPlaylist.video: HLSPlaylist.mediaPlaylist(source: video, index: v),
            HLSPlaylist.audio: HLSPlaylist.mediaPlaylist(source: audio, index: a),
        ])
        guard let url = HLSPlaylist.url(HLSPlaylist.master) else { throw Failure.badPlaylistURL }
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        return ComposedStream(item: AVPlayerItem(asset: asset), loader: loader)
    }
}
