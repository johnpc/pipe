import SwiftUI

/// Offline downloads: play from the local file, swipe to delete.
struct DownloadsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var downloads: DownloadStore

    var body: some View {
        List {
            if !downloads.items.isEmpty {
                Section {
                    EmptyView()
                } footer: {
                    Text("\(downloads.items.count) downloaded · \(DownloadFormat.storageText(bytes: downloads.totalStorageBytes())) used")
                        .accessibilityIdentifier("storageFooter")
                }
            }
            ForEach(downloads.items) { item in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: item.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 80, height: 45).clipped().cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline).lineLimit(2)
                        Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { play(item) }
                .accessibilityIdentifier("downloadRow")
            }
            .onDelete { downloads.remove(at: $0) }
        }
        .listStyle(.plain)
        .navigationTitle("Downloads")
        .overlay {
            if downloads.items.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle",
                                       description: Text("Download videos to play them offline"))
            }
        }
    }

    private func play(_ item: DownloadedItem) {
        // Local URL is resolved inside playItem via the injected DownloadStore.
        player.play(videoId: item.videoId, urlString: "", title: item.title, artist: item.artist, thumbnail: item.thumbnail, duration: item.duration)
    }
}
