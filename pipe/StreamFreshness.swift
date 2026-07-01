import Foundation

/// Pure decision for whether a queue item's stored stream URLs are stale and
/// should be re-resolved before playback. Piped/googlevideo URLs are
/// time-limited, so an item paused overnight — or a long video whose URL
/// expires mid-play — needs a fresh URL fetched from its videoId.
enum StreamFreshness {
    /// URLs older than this are treated as expired and re-resolved. Conservative
    /// vs. typical googlevideo lifetimes (~6h), leaving ample margin.
    static let maxAge: TimeInterval = 3600  // 1 hour

    /// Whether `item` needs re-resolution as of `now`.
    /// - Local/downloaded playback never needs it (caller passes `isLocal`).
    /// - A missing `resolvedAt` (queue persisted before the field existed, or an
    ///   item with no known resolve time) counts as stale.
    static func needsRefresh(resolvedAt: Date?, now: Date, isLocal: Bool) -> Bool {
        if isLocal { return false }
        guard let resolvedAt else { return true }
        return now.timeIntervalSince(resolvedAt) >= maxAge
    }
}
