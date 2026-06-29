import SwiftUI

/// Routes the selected bottom-tab index to its screen, honoring Offline Mode
/// (Feed→Downloads, Search→offline placeholder; Recents/Following are local and
/// unaffected). Extracted from ContentView so that file stays under the limit
/// and the offline routing lives in one place via the pure OfflineLogic.
struct MainTabContent: View {
    let selectedTab: Int
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var saved: SavedStore
    @ObservedObject var downloads: DownloadStore

    var body: some View {
        NavigationStack {
            switch OfflineLogic.screen(forTab: selectedTab, offline: settings.offlineMode) {
            case .feed:
                FeedView(player: player, following: following, recents: recents, saved: saved, downloads: downloads)
            case .search:
                SearchView(player: player, following: following, recents: recents, settings: settings, saved: saved, downloads: downloads)
            case .recents:
                RecentsView(player: player, recents: recents)
            case .following:
                FollowingView(player: player, following: following, recents: recents)
            case .downloads:
                DownloadsView(player: player, downloads: downloads)
            case .offlinePlaceholder:
                OfflinePlaceholderView()
            }
        }
    }
}
