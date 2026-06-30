import SwiftUI

struct DetailView: View {
    let videoId: String
    @ObservedObject var player: PlayerState
    @State private var state: LoadState<StreamResponse> = .loading
    @State private var showComments = false

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
            Button { showComments = true } label: { Image(systemName: "text.bubble") }
                .accessibilityIdentifier("commentsButton")
            if case .loaded(let s) = state, let downloads = player.downloads {
                DownloadButton(videoId: videoId, stream: s, downloads: downloads)
            }
            if let url = RowActions.youtubeURL(videoId: videoId) {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareButton")
            }
        }
        .sheet(isPresented: $showComments) { CommentsView(videoId: videoId) }
        .environment(\.openURL, OpenURLAction { url in handleLink(url) })
        .task { await load() }
    }

    /// Intercept pipe-seek:// links from the description to seek the player.
    private func handleLink(_ url: URL) -> OpenURLAction.Result {
        guard let secs = DescriptionLinks.seekSeconds(from: url) else { return .systemAction }
        player.seek(to: secs)
        return .handled
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
            if ChaptersLogic.hasChapters(s.chapters), let chapters = s.chapters {
                ChaptersView(chapters: chapters) { seekToChapter($0, in: s) }
            }
            if let d = s.description {
                Text(HTMLText.attributed(d)).font(.body).tint(.accentColor)
            }
            if let related = s.relatedStreams, !related.isEmpty {
                RelatedVideosView(related: related, player: player)
            }
        }
    }

    private func seekToChapter(_ chapter: Chapter, in s: StreamResponse) {
        let resolved = Playback.resolve(s, videoId: videoId)
        player.registerChapters(resolved.chapters, for: videoId)
        player.jumpTo(videoId: videoId, url: resolved.url, audioUrl: resolved.audioUrl, title: resolved.title, artist: resolved.artist, thumbnail: resolved.thumbnail, duration: resolved.duration, startAt: Double(chapter.start))
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
