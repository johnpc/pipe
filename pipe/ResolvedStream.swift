import Foundation

/// Value type carrying everything the player needs to start an item, produced by
/// `Playback.resolve` from a decoded `StreamResponse`.
struct ResolvedStream: Equatable {
    let videoId: String
    let url: String
    /// Proxied MP4 URL used when casting. The Chromecast receiver fetches media
    /// itself through a web context, so it needs the CORS-enabled Piped proxy
    /// rather than the host-rewritten direct googlevideo URL the phone uses.
    var castURL: String = ""
    let audioUrl: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
    let uploadedDate: String?
    var chapters: [Chapter] = []
}
