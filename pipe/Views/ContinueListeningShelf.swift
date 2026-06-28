import SwiftUI

/// Horizontal shelf of in-progress items shown atop the Feed; tap to resume.
struct ContinueListeningShelf: View {
    @ObservedObject var recents: RecentsStore
    let onPlay: (RecentItem) -> Void

    private var items: [RecentItem] { ContinueListeningLogic.inProgress(recents.items) }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue Listening").font(.headline).padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in card(item) }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func card(_ item: RecentItem) -> some View {
        Button { onPlay(item) } label: {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: item.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 160, height: 90).clipped().cornerRadius(8)
                    ProgressView(value: min(item.timestamp / Double(max(item.duration, 1)), 1))
                        .tint(.accentColor).padding(6)
                }
                Text(item.title).font(.caption).lineLimit(2).frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueCard")
        .accessibilityLabel("Resume \(item.title)")
    }
}
