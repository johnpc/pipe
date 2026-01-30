import SwiftUI

struct FullPlayerSheet: View {
    @ObservedObject var player: PlayerState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top)
                
                AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable().scaledToFit() } placeholder: { Color.gray }
                    .frame(maxWidth: 260, maxHeight: 260).cornerRadius(8)
                
                Text(player.currentTitle ?? "").font(.title3).bold().lineLimit(2).multilineTextAlignment(.center).padding(.horizontal)
                Text(player.currentArtist ?? "").foregroundStyle(.secondary)
                
                VStack {
                    Slider(value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ), in: 0...max(player.duration, 1))
                    .tint(.accentColor)
                    HStack {
                        Text(formatTime(player.currentTime)).font(.caption)
                        Spacer()
                        Text(formatTime(player.duration)).font(.caption)
                    }.foregroundStyle(.secondary)
                }.padding(.horizontal, 30)
                
                HStack(spacing: 36) {
                    Button { player.playPrevious() } label: { Image(systemName: "backward.fill").font(.title2) }
                        .disabled(player.currentIndex <= 0)
                    Button { player.skip(-10) } label: { Image(systemName: "gobackward.10").font(.title2) }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 60))
                    }
                    Button { player.skip(10) } label: { Image(systemName: "goforward.10").font(.title2) }
                    Button { player.playNext() } label: { Image(systemName: "forward.fill").font(.title2) }
                        .disabled(player.currentIndex >= player.queue.count - 1)
                }
                
                HStack {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { s in
                        Button { player.setSpeed(Float(s)) } label: {
                            Text(s == 1 ? "1x" : "\(s, specifier: "%.1f")x")
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(player.playbackSpeed == Float(s) ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(player.playbackSpeed == Float(s) ? .white : .primary)
                                .cornerRadius(12)
                        }
                    }
                }.font(.footnote)
                
                QueueSection(player: player)
            }
            .padding(.bottom, 30)
        }
    }
}

struct QueueSection: View {
    @ObservedObject var player: PlayerState
    
    var body: some View {
        if !player.queue.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Queue").font(.headline)
                    Spacer()
                    if player.queue.count > 1 {
                        Text("\(player.queue.count) items").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal)
                
                Divider()
                
                ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, item in
                    QueueRow(player: player, item: item, index: index)
                }
            }
            .padding(.top, 20)
        }
    }
}

struct QueueRow: View {
    @ObservedObject var player: PlayerState
    let item: QueueItem
    let index: Int
    
    var body: some View {
        HStack {
            if index == player.currentIndex {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
            } else {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            AsyncImage(url: URL(string: item.thumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 44, height: 44).cornerRadius(4)
            VStack(alignment: .leading) {
                Text(item.title).font(.subheadline).lineLimit(1)
                    .fontWeight(index == player.currentIndex ? .semibold : .regular)
                Text(item.artist).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if index != player.currentIndex {
                Button { player.removeFromQueue(at: index) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { player.playIndex(index) }
    }
}
