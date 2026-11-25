import Foundation

/// How the feed is ordered.
enum FeedSort: String, CaseIterable {
    case newest
    case channel

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .channel: return "By Channel"
        }
    }
}

/// The feed split by what each row is right now: streams on air, premieres
/// and streams still to come (soonest first), and the uploads. Live rows carry
/// `uploaded == -1` and upcoming ones a future time, so left in the main list
/// they sink to the bottom or pin to the top; sections put them where they read.
struct FeedSections: Equatable {
    var live: [RelatedStream] = []
    var upcoming: [RelatedStream] = []
    var videos: [RelatedStream] = []

    var isEmpty: Bool { live.isEmpty && upcoming.isEmpty && videos.isEmpty }
}

/// Pure feed ordering + filtering so it's unit-testable and keeps the view thin.
enum FeedLogic {
    static func sections(_ videos: [RelatedStream], sort: FeedSort, hideWatched: Bool, now: Date = Date(),
                         isWatched: (RelatedStream) -> Bool) -> FeedSections {
        var out = FeedSections()
        var starts: [String: Date] = [:]
        var uploads: [RelatedStream] = []
        for video in videos {
            switch StreamStatus.of(duration: video.duration, uploadedDate: video.uploadedDate, now: now) {
            case .live: out.live.append(video)
            case .upcoming(let start): starts[video.videoId] = start; out.upcoming.append(video)
            case .video: uploads.append(video)
            }
        }
        out.upcoming.sort { (starts[$0.videoId] ?? .distantFuture) < (starts[$1.videoId] ?? .distantFuture) }
        out.videos = arrange(uploads, sort: sort, hideWatched: hideWatched, isWatched: isWatched)
        return out
    }

    /// Sort and optionally hide watched videos.
    /// `isWatched` is injected (backed by RecentsStore.isCompleted in the app).
    static func arrange(
        _ videos: [RelatedStream],
        sort: FeedSort,
        hideWatched: Bool,
        isWatched: (RelatedStream) -> Bool
    ) -> [RelatedStream] {
        let filtered = hideWatched ? videos.filter { !isWatched($0) } : videos
        switch sort {
        case .newest:
            return filtered.sorted { ($0.uploaded ?? 0) > ($1.uploaded ?? 0) }
        case .channel:
            // Group by uploader, then newest within each channel; stable on name.
            return filtered.sorted {
                let a = $0.uploaderName ?? "", b = $1.uploaderName ?? ""
                if a != b { return a.localizedCaseInsensitiveCompare(b) == .orderedAscending }
                return ($0.uploaded ?? 0) > ($1.uploaded ?? 0)
            }
        }
    }
}
