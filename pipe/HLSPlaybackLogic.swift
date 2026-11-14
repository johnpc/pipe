import Foundation

/// Pure decisions for the native-HLS playback path.
enum HLSPlaybackLogic {
    /// Play via YouTube's HLS master whenever the instance offered one for a
    /// streamed item. Downloaded items keep playing their local file.
    static func usesHLS(_ item: QueueItem, isLocal: Bool) -> Bool {
        !isLocal && !item.hlsUrl.isEmpty
    }

    /// Index of the audible media-selection option to pick for `preferred`,
    /// given each option's language tag: exact or regional match, else English,
    /// else nil (leave AVPlayer's default). "original" has no tag to match on.
    static func audioSelection(tags: [String?], preferred: String) -> Int? {
        for language in [preferred, AudioLanguageLogic.english] where language != AudioLanguageLogic.original {
            if let index = tags.firstIndex(where: { AudioLanguageLogic.matches($0, language) }) { return index }
        }
        return nil
    }
}
