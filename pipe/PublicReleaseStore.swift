import Foundation

/// When each late-published feed video (see `FeedPublication`) first became
/// visible to this viewer, in epoch milliseconds to match `RelatedStream.uploaded`.
/// Backed by UserDefaults so the ordering survives relaunches; pruned to the
/// videos still in the feed so it never grows unbounded.
final class PublicReleaseStore {
    private let defaults: UserDefaults
    private let key = "feedPublicReleases"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Opt out of MainActor-isolated deinit (see the other stores).
    nonisolated deinit {}

    var dates: [String: Int64] {
        (defaults.dictionary(forKey: key) as? [String: NSNumber])?.mapValues(\.int64Value) ?? [:]
    }

    /// Stamp `ids` as released at `now`; an id already stamped keeps its first date.
    func record(_ ids: Set<String>, at now: Date = Date()) {
        guard !ids.isEmpty else { return }
        var current = dates
        let stamp = Int64(now.timeIntervalSince1970 * 1000)
        for id in ids where current[id] == nil { current[id] = stamp }
        save(current)
    }

    /// Forget videos the feed no longer lists.
    func prune(keeping ids: Set<String>) {
        let kept = dates.filter { ids.contains($0.key) }
        if kept.count != dates.count { save(kept) }
    }

    private func save(_ values: [String: Int64]) {
        defaults.set(values.mapValues { NSNumber(value: $0) }, forKey: key)
    }
}
