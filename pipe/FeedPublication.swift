import Foundation

/// Members-early uploads. A channel can release a video to its members days
/// before everyone else; Piped reports the original upload time, so when the
/// video finally appears for a non-member it lands deep in the feed instead of
/// at the top. A video the feed has never shown, whose upload time is older
/// than a video already known from the same channel, must have been held back:
/// it is treated as published the moment it first shows up. Pure; the dates
/// persist in `PublicReleaseStore`.
enum FeedPublication {
    /// Ids in `fresh` that first appear now yet predate a known video of theirs.
    static func latePublications(fresh: [RelatedStream], known: [RelatedStream]) -> Set<String> {
        guard !known.isEmpty else { return [] }
        let knownIds = Set(known.map(\.videoId))
        var newestKnown: [String: Int64] = [:]
        for video in known {
            guard let uploaded = video.uploaded, uploaded > 0 else { continue }
            newestKnown[channelKey(video)] = max(newestKnown[channelKey(video)] ?? 0, uploaded)
        }
        let late = fresh.filter { video in
            guard !knownIds.contains(video.videoId), let uploaded = video.uploaded, uploaded > 0,
                  let newest = newestKnown[channelKey(video)] else { return false }
            return uploaded < newest
        }
        return Set(late.map(\.videoId))
    }

    /// `videos` with each late publication's `uploaded` moved to its public
    /// release time, so newest-first ordering puts it where the viewer saw it land.
    static func applying(_ publicAt: [String: Int64], to videos: [RelatedStream]) -> [RelatedStream] {
        videos.map { video in
            guard let at = publicAt[video.videoId], at > (video.uploaded ?? 0) else { return video }
            return RelatedStream(url: video.url, title: video.title, thumbnail: video.thumbnail, duration: video.duration,
                                 uploaderName: video.uploaderName, uploadedDate: video.uploadedDate, uploaded: at,
                                 uploaderUrl: video.uploaderUrl)
        }
    }

    /// The channel URL when Piped sent one (two channels can share a display
    /// name), else the uploader's name.
    static func channelKey(_ video: RelatedStream) -> String { video.uploaderUrl ?? video.uploaderName ?? "" }
}
