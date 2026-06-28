import SwiftUI

/// Routes a Feed toolbar destination string to its screen. Extracted so the
/// routing is a single-purpose, render-testable view rather than a branchy
/// closure inside FeedView.
struct FeedDestination: View {
    let dest: String
    @ObservedObject var player: PlayerState
    @ObservedObject var saved: SavedStore
    @ObservedObject var downloads: DownloadStore

    var body: some View {
        switch dest {
        case "downloads": DownloadsView(player: player, downloads: downloads)
        case "trending": TrendingView(player: player)
        case "playlists": SavedPlaylistsView(player: player, saved: .shared)
        default: SavedView(player: player, saved: saved)
        }
    }
}
