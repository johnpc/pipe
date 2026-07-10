import SwiftUI

/// Explore: trending videos for a region. Reachable from the Feed; useful when a
/// new user follows no channels and the Feed is empty.
struct TrendingView: View {
    @ObservedObject var player: PlayerState
    @State private var state: LoadState<[RelatedStream]> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading: ProgressView("Loading trending…")
            case .failed: RetryView { Task { await load() } }
            case .loaded(let videos):
                if videos.isEmpty {
                    ContentUnavailableView("Nothing Trending", systemImage: "flame")
                } else {
                    List(videos) { v in
                        NavigationLink(value: v) {
                            VideoRow(v: v, onPlay: { run(v, .play) }, onQueue: { run(v, .queue) },
                                     onPlayNext: { run(v, .playNext) },
                                     onCast: { Playback.cast(videoId: v.videoId, player: player) })
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Trending")
        .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        state = LoadState.from(try? await PipedAPI.trending())
    }

    private func run(_ v: RelatedStream, _ action: Playback.Action) {
        Task { await Playback.run(videoId: v.videoId, action: action, player: player) }
    }
}
