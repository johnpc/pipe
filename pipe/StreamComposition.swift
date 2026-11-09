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

/// Builds the `AVPlayerItem` that plays a video-only track and a separate audio
/// track in lockstep. Both are fragmented MP4s streamed over HTTP; AVFoundation
/// reads each one's track table, and the composition references the remote
/// tracks directly — nothing is downloaded up front.
enum StreamComposition {
    enum Failure: Error {
        /// One of the sources lacks the expected media track (e.g. the "video"
        /// URL actually served audio, or an unplayable codec hid the track).
        case missingTrack
    }

    @MainActor static func playerItem(video: URL, audio: URL) async throws -> AVPlayerItem {
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let videoAsset = AVURLAsset(url: video, options: options)
        let audioAsset = AVURLAsset(url: audio, options: options)
        let (videoTracks, videoDuration) = try await videoAsset.load(.tracks, .duration)
        let (audioTracks, audioDuration) = try await audioAsset.load(.tracks, .duration)

        let composition = AVMutableComposition()
        guard let videoTrack = videoTracks.first(where: { $0.mediaType == .video }),
              let audioTrack = audioTracks.first(where: { $0.mediaType == .audio }),
              let videoSlot = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioSlot = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.missingTrack }

        // Trim to the shorter track so the composition never has a silent or
        // frozen tail where only one source still has samples.
        let range = CMTimeRange(start: .zero, duration: CMTimeMinimum(videoDuration, audioDuration))
        try videoSlot.insertTimeRange(range, of: videoTrack, at: .zero)
        try audioSlot.insertTimeRange(range, of: audioTrack, at: .zero)
        return AVPlayerItem(asset: composition)
    }
}
