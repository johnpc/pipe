import SwiftUI

/// Lists playlists the user has saved; tapping one reopens it in PlaylistView.
struct SavedPlaylistsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var saved: SavedPlaylistsStore

    var body: some View {
        List {
            ForEach(saved.playlists) { pl in
                NavigationLink(value: pl) {
                    PlaylistRow(item: PlaylistItem(url: pl.playlistId, name: pl.name,
                                                   thumbnail: pl.thumbnail, uploaderName: pl.uploader, videos: nil))
                }
            }
            .onDelete { offsets in
                for i in offsets { saved.remove(playlistId: saved.playlists[i].playlistId) }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Saved Playlists")
        .navigationDestination(for: SavedPlaylist.self) { pl in
            PlaylistView(playlistId: pl.playlistId, title: pl.name, player: player, saved: saved)
        }
        .overlay {
            if saved.playlists.isEmpty {
                ContentUnavailableView("No Saved Playlists", systemImage: "square.stack",
                                       description: Text("Save a playlist to find it here"))
            }
        }
    }
}
