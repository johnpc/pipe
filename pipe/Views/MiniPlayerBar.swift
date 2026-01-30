import SwiftUI

struct MiniPlayerBar: View {
    @ObservedObject var player: PlayerState
    @State private var showFull = false
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: player.currentTime, total: max(player.duration, 1))
                .tint(.accentColor)
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
            
            HStack {
                AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 40, height: 40).cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTitle ?? "").font(.footnote).lineLimit(1)
                    Text(player.currentArtist ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
        }
        .contentShape(Rectangle())
        .onTapGesture { showFull = true }
        .sheet(isPresented: $showFull) { FullPlayerSheet(player: player) }
    }
}
