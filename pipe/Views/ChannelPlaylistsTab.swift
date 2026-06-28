import SwiftUI

/// Renders a channel's "playlists" tab: a list of playlist rows that open into
/// PlaylistView. Extracted so ChannelView stays under the line limit and the
/// playlist navigation lives in one place.
struct ChannelPlaylistsTab: View {
    let playlists: [PlaylistItem]
    @ObservedObject var player: PlayerState

    var body: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: "square.stack")
            } else {
                List(playlists) { pl in
                    NavigationLink(value: pl) { PlaylistRow(item: pl) }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: PlaylistItem.self) { pl in
            PlaylistView(playlistId: pl.playlistId, title: pl.displayName,
                         player: player, saved: .shared)
        }
    }
}
