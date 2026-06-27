import Foundation

/// Pure helpers for row actions (share links, channel links). Kept out of the
/// views so the URL construction is unit-testable.
enum RowActions {
    /// Public YouTube watch URL for a video id — used by Share.
    static func youtubeURL(videoId: String) -> URL? {
        let trimmed = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://youtube.com/watch?v=\(trimmed)")
    }

    /// Public YouTube channel URL for a channel id.
    static func youtubeChannelURL(channelId: String) -> URL? {
        let trimmed = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://youtube.com/channel/\(trimmed)")
    }
}
