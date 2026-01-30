import SwiftUI

struct RecentsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var recents: RecentsStore
    
    var body: some View {
        List {
            ForEach(recents.items, id: \.videoId) { (item: RecentItem) in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: URL(string: item.thumbnail)) { img in img.resizable().scaledToFill() } placeholder: { Color.gray }
                                .frame(width: 100, height: 56).clipped().cornerRadius(6)
                            if item.duration > 0 {
                                Text(formatDuration(item.duration))
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .padding(4)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.tail)
                            if item.timestamp > 10 {
                                Text("Resume at \(formatTime(item.timestamp))").font(.caption2).foregroundColor(.accentColor)
                            }
                        }
                        
                        Spacer()
                        
                        Button { playItem(item) } label: {
                            Image(systemName: "play.circle.fill").font(.title2)
                        }.buttonStyle(.plain)
                        Button { queueItem(item) } label: {
                            Image(systemName: "text.badge.plus").font(.title3)
                        }.buttonStyle(.plain)
                    }
                    
                    Text(item.title).font(.subheadline).lineLimit(3)
                }
                .padding(.vertical, 8)
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
    
    private func queueItem(_ item: RecentItem) {
        Task {
            guard let stream = try? await PipedAPI.streams(item.videoId) else { return }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.addToQueue(videoId: item.videoId, url: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration)
            }
        }
    }
}
