import Foundation

/// In-memory cache of resolved stream metadata, keyed by video id.
///
/// Every play tap used to refetch `/streams/{id}` even when the video was just
/// resolved (its detail page was open, or it played minutes ago). The Piped
/// extractor round-trip is the slow part of "Loading..." — often seconds — so
/// serving a still-fresh response makes those plays start instantly. Entries
/// expire on the same clock as `StreamFreshness`, so nothing this cache serves
/// is older than what the app would already treat as playable.
enum StreamCache {
    struct Entry {
        let response: StreamResponse
        let resolvedAt: Date
    }

    /// Main-actor-confined in practice (all callers are UI flows), matching the
    /// `PipedAPI.session` precedent.
    nonisolated(unsafe) private(set) static var entries: [String: Entry] = [:]

    /// Bound on memory: plenty for a browsing session, tiny in bytes.
    static let maxEntries = 24

    /// The cached response for `videoId`, or nil when absent or expired.
    static func get(_ videoId: String, now: Date = Date()) -> StreamResponse? {
        guard let entry = entries[videoId],
              !StreamFreshness.needsRefresh(resolvedAt: entry.resolvedAt, now: now, isLocal: false)
        else { return nil }
        return entry.response
    }

    static func put(_ videoId: String, _ response: StreamResponse, now: Date = Date()) {
        if entries[videoId] == nil, entries.count >= maxEntries,
           let oldest = entries.min(by: { $0.value.resolvedAt < $1.value.resolvedAt })?.key {
            entries.removeValue(forKey: oldest)
        }
        entries[videoId] = Entry(response: response, resolvedAt: now)
    }

    static func removeAll() { entries.removeAll() }
}
