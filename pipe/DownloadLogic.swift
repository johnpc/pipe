import Foundation

/// Metadata for a downloaded item (the file lives on disk; this is persisted).
struct DownloadedItem: Codable, Identifiable, Equatable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
    /// File name (not full path) of the downloaded media within the downloads dir.
    let fileName: String
}

/// Pure download helpers so path/state logic is unit-testable without disk.
enum DownloadLogic {
    /// Deterministic on-disk file name for a video's downloaded media.
    /// Sanitizes the id so it's always a safe single path component.
    static func fileName(for videoId: String, ext: String = "mp4") -> String {
        let safe = videoId.unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber || c == "-" || c == "_") ? c : "_"
        }
        return "dl_\(String(safe)).\(ext)"
    }

    /// Pick the source URL to download: prefer audio-only (smaller) when present,
    /// else the video URL.
    static func downloadURL(audioUrl: String, videoUrl: String) -> String? {
        if !audioUrl.isEmpty { return audioUrl }
        if !videoUrl.isEmpty { return videoUrl }
        return nil
    }
}
