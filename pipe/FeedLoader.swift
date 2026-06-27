import Foundation

/// Loads the followed-channels feed: fan-out fetch, cache, sort. Kept out of the
/// view so FeedView only renders and this orchestration is reusable/testable.
enum FeedLoader {
    /// Fetch the latest videos across all followed channels, sorted newest-first.
    /// Returns nil when the network yielded nothing (so the caller can keep
    /// showing cached content).
    static func fetch(channels: [FollowedChannel]) async -> [RelatedStream]? {
        guard !channels.isEmpty else { return [] }
        var all: [RelatedStream] = []
        await withTaskGroup(of: [RelatedStream].self) { group in
            for channel in channels {
                group.addTask { (try? await PipedAPI.channel(channel.id).relatedStreams) ?? [] }
            }
            for await streams in group { all.append(contentsOf: streams) }
        }
        guard !all.isEmpty else { return nil }
        return all.sorted { ($0.uploaded ?? 0) > ($1.uploaded ?? 0) }
    }
}
