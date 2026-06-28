import SwiftUI

/// Header for a playlist detail: title, uploader, and the Play All / Save
/// actions. Extracted so PlaylistView stays declarative and under the line limit.
struct PlaylistHeader: View {
    let playlist: PlaylistResponse
    let isSaved: Bool
    let onPlayAll: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(playlist.name).font(.title3).bold().lineLimit(2)
            if let uploader = playlist.uploader, !uploader.isEmpty {
                Text(uploader).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button(action: onPlayAll) {
                    Label("Play All", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("playAllButton")

                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("savePlaylistButton")
                .accessibilityLabel(isSaved ? "Remove Playlist" : "Save Playlist")
            }
        }
        .padding()
    }
}
