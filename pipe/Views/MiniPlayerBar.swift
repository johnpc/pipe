import SwiftUI

struct MiniPlayerBar: View {
    @ObservedObject var player: PlayerState
    @State private var showFull = false
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: player.currentTime, total: max(player.duration, 1)).tint(.accentColor)
            
            HStack {
                AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 44, height: 44).cornerRadius(4)
                
                VStack(alignment: .leading) {
                    Text(player.currentTitle ?? "").font(.footnote).lineLimit(1)
                    Text(player.currentArtist ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                }
            }.padding(10)
        }
        .background(.thinMaterial)
        .onTapGesture { showFull = true }
        .sheet(isPresented: $showFull) { FullPlayerSheet(player: player) }
    }
}
