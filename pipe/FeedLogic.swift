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

/// Pure feed ordering + filtering so it's unit-testable and keeps the view thin.
enum FeedLogic {
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
