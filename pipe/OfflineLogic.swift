import Foundation

/// Pure decisions for what each bottom tab shows, so routing is unit-testable
/// without views.
///
/// Two conditions change the network-backed tabs (Feed, Search): **no instance
/// configured** (pipe ships without a server) shows the setup screen, and
/// **Offline Mode** shows Downloads / an offline placeholder. Local-data tabs
/// (Recents, Following) always render — they read persisted state, not the API.
enum OfflineLogic {
    /// What a tab index should render.
    enum Screen: Equatable {
        case feed, search, recents, following
        case downloads           // offline substitute for the Feed (home) tab
        case offlinePlaceholder  // offline substitute for Search
        case instanceSetup       // no instance configured: Feed and Search ask for one
    }

    /// The home tab index, surfaced so callers can route there when offline mode
    /// is toggled on.
    static let homeTab = 0

    static func screen(forTab tab: Int, offline: Bool, configured: Bool = true) -> Screen {
        switch tab {
        case 2: return .recents
        case 3: return .following
        case 1:
            if offline { return .offlinePlaceholder }
            return configured ? .search : .instanceSetup
        default:
            if offline { return .downloads }
            return configured ? .feed : .instanceSetup
        }
    }
}
