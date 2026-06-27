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
                            Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                            if let date = item.uploadedDate {
                                Text(formatUploadDate(date)).font(.caption2).foregroundStyle(.tertiary)
                            }
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
                .contextMenu {
                    Button { playItem(item) } label: { Label("Play", systemImage: "play.fill") }
                    Button { queueItem(item) } label: { Label("Add to Queue", systemImage: "text.badge.plus") }
                    if let url = RowActions.youtubeURL(videoId: item.videoId) {
                        ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { recents.remove(videoId: item.videoId) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onDelete { recents.remove(at: $0) }
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
        Task { await Playback.run(videoId: item.videoId, action: .play, player: player) }
    }

    private func queueItem(_ item: RecentItem) {
        Task { await Playback.run(videoId: item.videoId, action: .queue, player: player) }
    }
}
