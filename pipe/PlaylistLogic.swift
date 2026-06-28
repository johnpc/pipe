import Foundation

/// Pure helpers for playlists: extracting the id from a Piped playlist URL and
/// mapping a playlist's videos into queue entries. Kept free of UI/network so
/// it's fully unit-testable.
enum PlaylistLogic {
    /// Piped playlist URLs look like "/playlist?list=<id>" (sometimes a full
    /// URL). Returns the bare list id, or the input unchanged if no id is found.
    static func id(fromURL url: String) -> String {
        guard let range = url.range(of: "list=") else {
            // Already a bare id, or an unexpected shape — strip a leading slash.
            return url.hasPrefix("/") ? String(url.dropFirst()) : url
        }
        let after = url[range.upperBound...]
        // Stop at the next query separator if present.
        if let amp = after.firstIndex(of: "&") {
            return String(after[..<amp])
        }
        return String(after)
    }

    /// Videos in a playlist that are actually playable (have a resolvable id).
    /// Order is preserved — playlists play top-to-bottom.
    static func playableVideos(_ playlist: PlaylistResponse) -> [RelatedStream] {
        playlist.relatedStreams.filter { !$0.videoId.isEmpty }
    }
}
