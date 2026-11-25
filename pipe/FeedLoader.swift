import Foundation

/// Loads the followed-channels feed: fan-out fetch, late-publication ordering,
/// sort. Kept out of the view so FeedView only renders and this orchestration
/// is reusable/testable.
enum FeedLoader {
    /// Fetch the latest videos across all followed channels, sorted newest-first
    /// by public release. `known` is what the feed showed before (cached or on
    /// screen), used to spot videos that were held back for members. Returns
    /// nil when the network yielded nothing (so the caller keeps cached content).
    static func fetch(channels: [FollowedChannel], known: [RelatedStream] = [],
                      releases: PublicReleaseStore = PublicReleaseStore()) async -> [RelatedStream]? {
        guard !channels.isEmpty else { return [] }
        var all: [RelatedStream] = []
        await withTaskGroup(of: [RelatedStream].self) { group in
            for channel in channels {
                group.addTask { (try? await PipedAPI.channel(channel.id).relatedStreams) ?? [] }
            }
            for await streams in group { all.append(contentsOf: streams) }
        }
        guard !all.isEmpty else { return nil }
        return arrange(all, known: known, releases: releases)
    }

    /// Stamp newly visible late publications, drop stale stamps, and sort by
    /// public release, newest first. Separate from the fetch so it is unit-tested.
    static func arrange(_ fresh: [RelatedStream], known: [RelatedStream], releases: PublicReleaseStore,
                        now: Date = Date()) -> [RelatedStream] {
        releases.record(FeedPublication.latePublications(fresh: fresh, known: known), at: now)
        releases.prune(keeping: Set(fresh.map(\.videoId)))
        return FeedPublication.applying(releases.dates, to: fresh).sorted { ($0.uploaded ?? 0) > ($1.uploaded ?? 0) }
    }
}
