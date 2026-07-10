import Foundation

/// Pure builder that turns a resolved stream (or a queued item) into the
/// `CastMedia` a receiver needs. Casting always targets a TV, so it uses the
/// **full A/V video URL** — never the audio-only track the phone might prefer.
/// Kept free of the Cast SDK and of any state so it's exhaustively unit-testable,
/// mirroring `Playback.resolve` and `SearchLogic`.
enum CastLogic {
    /// MIME type advertised to the receiver. The app resolves progressive MP4
    /// video URLs (`getStreamUrl`), which the default media receiver plays.
    static let videoContentType = "video/mp4"

    /// Build cast media from the discrete stream fields. `startTime` is clamped
    /// to a non-negative value so a garbage position never rejects the load.
    static func media(url: String,
                      title: String,
                      artist: String,
                      thumbnail: String,
                      startTime: Double) -> CastMedia {
        CastMedia(url: url,
                  contentType: videoContentType,
                  title: title,
                  artist: artist,
                  thumbnail: thumbnail,
                  startTime: max(0, startTime))
    }

    /// Build cast media from a freshly resolved stream (video-row / play flow).
    static func media(from resolved: ResolvedStream, startTime: Double = 0) -> CastMedia {
        media(url: resolved.url,
              title: resolved.title,
              artist: resolved.artist,
              thumbnail: resolved.thumbnail,
              startTime: startTime)
    }

    /// Build cast media from a queued item (in-flight handoff / queue advance).
    /// Uses the item's video URL directly regardless of the phone's audio mode.
    static func media(from item: QueueItem, startTime: Double = 0) -> CastMedia {
        media(url: item.url,
              title: item.title,
              artist: item.artist,
              thumbnail: item.thumbnail,
              startTime: startTime)
    }

    /// Whether an item can actually be cast: it needs a non-empty video URL.
    /// Callers show an error instead of loading a receiver with a dead URL.
    static func isCastable(_ media: CastMedia) -> Bool {
        !media.url.isEmpty
    }
}
