import Foundation

/// Pure paging helpers so list pagination is unit-testable.
enum Pagination {
    /// Append a new page to existing items, de-duplicating by video id and
    /// preserving order (existing first, then new). Piped sometimes repeats
    /// items across page boundaries, so dedup matters.
    static func merge(_ existing: [RelatedStream], _ page: [RelatedStream]) -> [RelatedStream] {
        var seen = Set(existing.map(\.videoId))
        var result = existing
        for item in page where !seen.contains(item.videoId) {
            seen.insert(item.videoId)
            result.append(item)
        }
        return result
    }

    /// Whether more pages are available (a non-empty next-page token).
    static func hasMore(_ token: String?) -> Bool {
        guard let token else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
