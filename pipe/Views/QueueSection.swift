import SwiftUI

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
                    EditButton().font(.caption)
                }.padding(.horizontal)

                Divider()

                List {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, item in
                        QueueRow(player: player, item: item, index: index)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .onMove { player.moveQueueItem(from: $0, to: $1) }
                    .onDelete { player.removeFromQueue(at: $0) }
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(player.queue.count * 60))
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
                HStack {
                    Text(item.artist).font(.caption).foregroundStyle(.secondary)
                    if item.duration > 0 {
                        Text("•").font(.caption).foregroundStyle(.secondary)
                        Text(formatDuration(item.duration)).font(.caption).foregroundStyle(.secondary)
                    }
                }
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
