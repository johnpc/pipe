import Foundation

/// Pure cache-freshness logic, unit-testable without timers or disk.
enum FeedCachePolicy {
    /// Default time-to-live for a cached feed.
    static let ttl: TimeInterval = 15 * 60

    /// Whether a cache stamped at `cachedAt` is still fresh at `now`.
    static func isFresh(cachedAt: Date, now: Date, ttl: TimeInterval = ttl) -> Bool {
        now.timeIntervalSince(cachedAt) < ttl
    }
}

/// Disk/UserDefaults-backed cache of the feed's videos with a timestamp, so the
/// Feed renders instantly on launch and survives a flaky network. The view shows
/// cached items immediately, then refreshes in the background.
final class FeedCache {
    private let defaults: UserDefaults
    private let videosKey = "feedCacheVideos"
    private let stampKey = "feedCacheStamp"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Opt out of MainActor-isolated deinit to avoid the async executor-hop
    // double-free crash under the current toolchain (see the stores).
    nonisolated deinit {}

    /// Persist the freshly loaded feed with a timestamp.
    func save(_ videos: [RelatedStream], now: Date = Date()) {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        defaults.set(data, forKey: videosKey)
        defaults.set(now.timeIntervalSince1970, forKey: stampKey)
    }

    /// The cached videos, regardless of freshness (nil if nothing cached).
    func cachedVideos() -> [RelatedStream]? {
        guard let data = defaults.data(forKey: videosKey),
              let videos = try? JSONDecoder().decode([RelatedStream].self, from: data) else { return nil }
        return videos
    }

    /// When the cache was last written, or nil if never.
    func cachedAt() -> Date? {
        let t = defaults.double(forKey: stampKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// True when there's a cache and it's still within the TTL.
    func isFresh(now: Date = Date()) -> Bool {
        guard let stamp = cachedAt() else { return false }
        return FeedCachePolicy.isFresh(cachedAt: stamp, now: now)
    }
}
