import SwiftUI

/// A video's detail page: description, chapters, related videos, and comments —
/// browsable WITHOUT starting playback. Reached by tapping a video row in
/// Search, Feed, Recents, Trending, Channel, and Playlist lists.
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
                ScrollView { DetailContent(videoId: videoId, stream: s, player: player).padding() }
            }
        }
        .navigationTitle("Details")
        .toolbar {
            if case .loaded(let s) = state, let downloads = player.downloads {
                DownloadButton(videoId: videoId, stream: s, downloads: downloads)
            }
            if let url = RowActions.youtubeURL(videoId: videoId) {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareButton")
            }
        }
        .environment(\.openURL, OpenURLAction { url in handleLink(url) })
        .task { await load() }
    }

    /// Intercept pipe-seek:// links from the description to seek the player.
    private func handleLink(_ url: URL) -> OpenURLAction.Result {
        guard let secs = DescriptionLinks.seekSeconds(from: url) else { return .systemAction }
        player.seek(to: secs)
        return .handled
    }

    private func load() async {
        state = .loading
        state = LoadState.from(try? await PipedAPI.streams(videoId))
    }
}
