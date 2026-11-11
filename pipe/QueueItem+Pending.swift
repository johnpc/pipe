import Foundation

/// Queue items built from what a list row already knows (title, thumbnail,
/// duration) before any stream URL exists. They carry empty URLs and no
/// `resolvedAt`, which `playItem` treats as stale: if the background resolution
/// hasn't landed by the time the item is up, it re-resolves right before play.
extension QueueItem {
    static func pending(videoId: String, title: String, artist: String, thumbnail: String,
                        duration: Int, uploadedDate: String?) -> QueueItem {
        QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail,
                  url: "", audioUrl: "", duration: duration, uploadedDate: uploadedDate, resolvedAt: nil)
    }

    /// A feed / channel / trending / related / playlist row.
    init(pending v: RelatedStream) {
        self = .pending(videoId: v.videoId, title: v.title, artist: v.uploaderName ?? "",
                        thumbnail: v.thumbnail, duration: v.duration, uploadedDate: v.uploadedDate)
    }

    /// A search result row.
    init(pending item: SearchItem) {
        self = .pending(videoId: item.videoId, title: item.displayTitle, artist: item.displayUploader,
                        thumbnail: item.displayThumbnail, duration: item.duration ?? 0, uploadedDate: item.uploadedDate)
    }

    /// A watch-history row.
    init(pending item: RecentItem) {
        self = .pending(videoId: item.videoId, title: item.title, artist: item.artist,
                        thumbnail: item.thumbnail, duration: item.duration, uploadedDate: item.uploadedDate)
    }
}
