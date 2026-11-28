import Foundation

/// What kind of results a search shows. Sent to Piped as its `filter` value and
/// also applied to the rows that come back, so an instance (or the bundled
/// fixtures) that ignores the parameter still shows only the chosen kind.
enum SearchFilter: String, CaseIterable, Identifiable {
    case all, videos, channels, playlists

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .channels: return "Channels"
        case .playlists: return "Playlists"
        }
    }

    /// Piped's `filter=` query value.
    var pipedValue: String { rawValue }

    func matches(_ item: SearchItem) -> Bool {
        switch self {
        case .all: return true
        case .videos: return !item.isChannel && !item.isPlaylist
        case .channels: return item.isChannel
        case .playlists: return item.isPlaylist
        }
    }

    func apply(_ items: [SearchItem]) -> [SearchItem] {
        self == .all ? items : items.filter(matches)
    }
}
