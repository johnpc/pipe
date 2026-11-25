import Foundation

struct QueueItem: Identifiable, Equatable, Codable {
    var id = UUID()
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    /// Full A/V video stream URL. Mutable so it can be re-resolved when the
    /// Piped/googlevideo URL expires (they are time-limited).
    var url: String
    /// Audio-only stream URL (empty when the source had no audio-only track).
    var audioUrl: String
    /// Proxied MP4 URL for casting (CORS-friendly for the TV receiver). Mutable
    /// so it's re-resolved with `url` when the stream expires. Empty → falls back
    /// to `url` at cast time.
    var castUrl: String = ""
    /// Video-only MP4 URL (no audio track). In video mode it's paired with
    /// `audioUrl` in an `AVMutableComposition`, so the picture plays with the
    /// chosen audio language — the muxed `url` carries one fixed track. Empty
    /// when the source offers none (or for items queued before this existed);
    /// playback then falls back to `url`.
    var videoOnlyUrl: String = ""
    /// YouTube's HLS master playlist for the video (see `HLSPlaybackLogic`).
    /// Empty when the instance offered none; then the direct URLs above play.
    var hlsUrl: String = ""
    let duration: Int
    let uploadedDate: String?
    /// A stream in progress. Live items keep no resume position and are never
    /// marked completed or offered for download (see `RecentsPolicy`).
    var isLive: Bool = false
    /// When the stream URLs were last resolved. Used to detect a stale (expired)
    /// URL and re-fetch before playback. `nil` for items persisted before this
    /// field existed — treated as stale so they're refreshed on next play.
    var resolvedAt: Date? = Date()
    /// Audio language the user picked for this item in the player; nil means
    /// the Settings preference. Kept so a URL refresh stays in that language.
    var audioLanguage: String? = nil
    /// Progress of a background URL resolution for this item (prefetch of the
    /// next item, or the resolve behind an instant "Add to queue"). In-memory
    /// only; a relaunch starts over.
    var resolveAttempt: ResolveAttempt = .none

    /// Where this item's stream URLs stand. Derived from `resolvedAt` and
    /// `resolveAttempt`, so every reader asks one question instead of two.
    var resolution: StreamResolution {
        switch resolveAttempt {
        case .inFlight: return .resolving
        case .failed: return .failed
        case .none: return resolvedAt.map { .resolved($0) } ?? .pending
        }
    }

    // `id` is generated, not part of the persisted payload.
    enum CodingKeys: String, CodingKey {
        case videoId, title, artist, thumbnail, url, audioUrl, castUrl, duration, uploadedDate, resolvedAt
        case audioLanguage, videoOnlyUrl, hlsUrl, isLive
    }

    /// URL to play for the given mode: audio-only when available and not in
    /// video mode; otherwise the full video stream.
    func playbackURL(videoMode: Bool) -> String {
        (!videoMode && !audioUrl.isEmpty) ? audioUrl : url
    }

    /// URL to hand a Cast receiver: the proxied MP4 when available, else `url`.
    var castPlaybackURL: String { castUrl.isEmpty ? (url.isEmpty ? hlsUrl : url) : castUrl }
}

/// A background resolution in progress (`inFlight`) or one that failed, so the
/// periodic prefetch neither starts a second fetch nor hammers the instance.
/// The play path's own refresh is the retry after `failed`.
enum ResolveAttempt: Equatable {
    case none
    case inFlight
    case failed
}

/// The lifecycle of a queue item's stream URLs: queued from a list row with no
/// URLs yet (`pending`), being fetched (`resolving`), fetched at a time
/// (`resolved`; stale once older than `StreamFreshness.maxAge`), or a
/// background fetch failed (`failed`; the play path refreshes before playing).
enum StreamResolution: Equatable {
    case pending
    case resolving
    case resolved(Date)
    case failed

    /// True when a background fetch should not be started for this item.
    var isBusy: Bool { self == .resolving || self == .failed }
}

struct FollowedChannel: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let thumbnail: String
}
