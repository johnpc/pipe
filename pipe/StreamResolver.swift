import Foundation

/// Mints fresh stream URLs for a queue item from its video id. Injected into
/// `PlayerState` so refresh, prefetch, and failure-recovery tests can supply a
/// canned resolver instead of stubbing the global `PipedAPI.session`.
protocol StreamResolving {
    /// A copy of `item` with current URLs and `resolvedAt`, or nil when the
    /// fetch fails or yields nothing playable.
    func fresh(_ item: QueueItem) async -> QueueItem?
}

/// The production resolver: asks the Piped instance, bypassing its cache.
/// This path exists to mint a NEW URL (expired or dead on arrival), so
/// re-serving the cached one would fail identically.
struct PipedStreamResolver: StreamResolving {
    func fresh(_ item: QueueItem) async -> QueueItem? {
        guard let response = try? await PipedAPI.streams(item.videoId, bypassingCache: true) else { return nil }
        return Self.apply(response, to: item, language: item.audioLanguage ?? pipedAudioLanguage)
    }

    /// Pure: copy `response`'s URLs onto `item` and stamp it resolved now.
    static func apply(_ response: StreamResponse, to item: QueueItem, language: String, now: Date = Date()) -> QueueItem? {
        var copy = item
        copy.url = getStreamUrl(response)
        copy.audioUrl = getAudioStreamUrl(response, language: language)
        copy.castUrl = getCastStreamUrl(response)
        copy.videoOnlyUrl = getVideoOnlyStreamUrl(response)
        copy.hlsUrl = response.hls ?? ""
        copy.isLive = response.livestream == true
        copy.resolvedAt = now
        guard !copy.url.isEmpty || !copy.audioUrl.isEmpty || !copy.hlsUrl.isEmpty else { return nil }
        return copy
    }
}
