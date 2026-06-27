import SwiftUI

struct SavedView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var saved: SavedStore

    var body: some View {
        List {
            ForEach(saved.items) { item in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: item.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 80, height: 45).clipped().cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline).lineLimit(2)
                        Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { play(item) } label: {
                        Image(systemName: "play.circle.fill").font(.title2)
                    }.buttonStyle(.plain).accessibilityIdentifier("playButton")
                }
                .contextMenu {
                    Button { play(item) } label: { Label("Play", systemImage: "play.fill") }
                    if let url = RowActions.youtubeURL(videoId: item.videoId) {
                        ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { saved.remove(videoId: item.videoId) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onDelete { saved.remove(at: $0) }
        }
        .listStyle(.plain)
        .navigationTitle("Saved")
        .overlay {
            if saved.items.isEmpty {
                ContentUnavailableView("Nothing Saved", systemImage: "bookmark", description: Text("Save videos to watch later"))
            }
        }
    }

    private func play(_ item: SavedItem) {
        Task { await Playback.run(videoId: item.videoId, action: .play, player: player) }
    }
}
