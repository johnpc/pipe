import Foundation

/// Pure decisions for Offline Mode, so routing is unit-testable without views.
///
/// When offline, network-backed tabs (Feed, Search) can't load, so the home tab
/// shows Downloads and Search shows an offline placeholder. Local-data tabs
/// (Recents, Following) keep working — they read persisted state, not the API.
enum OfflineLogic {
    /// What a tab index should render, given offline state.
    enum Screen: Equatable {
        case feed, search, recents, following
        case downloads        // offline substitute for the Feed (home) tab
        case offlinePlaceholder  // offline substitute for Search
    }

    /// The home tab index, surfaced so callers can route there when offline mode
    /// is toggled on.
    static let homeTab = 0

    static func screen(forTab tab: Int, offline: Bool) -> Screen {
        switch tab {
        case 0: return offline ? .downloads : .feed
        case 1: return offline ? .offlinePlaceholder : .search
        case 2: return .recents
        case 3: return .following
        default: return offline ? .downloads : .feed
        }
    }
}
