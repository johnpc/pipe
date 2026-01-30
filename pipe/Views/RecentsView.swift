import SwiftUI

struct RecentsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var recents: RecentsStore
    
    var body: some View {
        List {
            ForEach(recents.items, id: \.videoId) { (item: RecentItem) in
                Button {
                    playItem(item)
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: item.thumbnail)) { img in img.resizable().scaledToFill() } placeholder: { Color.gray }
                            .frame(width: 100, height: 56).clipped().cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline).lineLimit(2)
                            Text(item.artist).font(.caption).foregroundStyle(.secondary)
                            if item.timestamp > 10 {
                                Text("Resume at \(formatTime(item.timestamp))").font(.caption2).foregroundColor(.accentColor)
                            }
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Recents")
        .overlay {
            if recents.items.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Videos you watch will appear here"))
            }
        }
    }
    
    private func playItem(_ item: RecentItem) {
        Task {
            guard let stream = try? await PipedAPI.streams(item.videoId) else { return }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.play(videoId: item.videoId, urlString: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration)
            }
        }
    }
}
