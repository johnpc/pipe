import Foundation

/// Custom decoding for QueueItem so a queue persisted before `resolvedAt`
/// existed decodes with `resolvedAt == nil` — i.e. treated as stale and
/// re-resolved on next play, rather than silently assumed fresh. Kept in an
/// extension so the memberwise initializer stays available for construction.
extension QueueItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            videoId: try c.decode(String.self, forKey: .videoId),
            title: try c.decode(String.self, forKey: .title),
            artist: try c.decode(String.self, forKey: .artist),
            thumbnail: try c.decode(String.self, forKey: .thumbnail),
            url: try c.decode(String.self, forKey: .url),
            audioUrl: try c.decode(String.self, forKey: .audioUrl),
            duration: try c.decode(Int.self, forKey: .duration),
            uploadedDate: try c.decodeIfPresent(String.self, forKey: .uploadedDate),
            resolvedAt: try c.decodeIfPresent(Date.self, forKey: .resolvedAt)
        )
    }
}
