import SwiftUI

struct DetailView: View {
    let videoId: String
    @ObservedObject var player: PlayerState
    @State private var state: LoadState<StreamResponse> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().padding()
            case .failed:
                RetryView { Task { await load() } }
            case .loaded(let s):
                ScrollView { loadedBody(s).padding() }
            }
        }
        .navigationTitle("Episode")
        .toolbar {
            if let url = RowActions.youtubeURL(videoId: videoId) {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareButton")
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func loadedBody(_ s: StreamResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: s.thumbnailUrl)) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 100, height: 100).cornerRadius(8)
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.title).font(.headline)
                    Text(s.uploader).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button { playNow(s) } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.subheadline)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.accentColor).foregroundColor(.white).cornerRadius(16)
                        }
                        Button { addToQueue(s) } label: {
                            Label("Queue", systemImage: "plus")
                                .font(.subheadline)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.2)).cornerRadius(16)
                        }
                    }
                }
            }
            if let d = s.description {
                Text(htmlToAttributedString(d)).font(.body)
            }
        }
    }

    private func load() async {
        state = .loading
        state = LoadState.from(try? await PipedAPI.streams(videoId))
    }


    private func playNow(_ s: StreamResponse) {
        Playback.apply(Playback.resolve(s, videoId: videoId), action: .play, to: player)
    }

    private func addToQueue(_ s: StreamResponse) {
        Playback.apply(Playback.resolve(s, videoId: videoId), action: .queue, to: player)
    }
}
