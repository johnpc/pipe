import SwiftUI

/// The loaded body of a video's detail page: header (thumbnail, title, uploader,
/// play/queue actions), chapters, description, related videos, and inline
/// comments. Extracted from DetailView so each file keeps one purpose.
struct DetailContent: View {
    let videoId: String
    let stream: StreamResponse
    @ObservedObject var player: PlayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if ChaptersLogic.hasChapters(stream.chapters), let chapters = stream.chapters {
                ChaptersView(chapters: chapters) { seekToChapter($0) }
            }
            if let d = stream.description {
                Text(HTMLText.attributed(d)).font(.body).tint(.accentColor)
            }
            if let related = stream.relatedStreams, !related.isEmpty {
                RelatedVideosView(related: related, player: player)
            }
            Text("Comments").font(.headline)
            CommentsList(videoId: videoId)
                .frame(minHeight: 320)
                .accessibilityIdentifier("detailComments")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            AsyncImage(url: URL(string: stream.thumbnailUrl)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 100, height: 100).cornerRadius(8)
            VStack(alignment: .leading, spacing: 8) {
                Text(stream.title).font(.headline)
                Text(stream.uploader).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button { run(.play) } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.accentColor).foregroundColor(.white).cornerRadius(16)
                    }
                    Button { run(.queue) } label: {
                        Label("Queue", systemImage: "plus")
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.2)).cornerRadius(16)
                    }
                }
            }
        }
    }

    private func run(_ action: Playback.Action) {
        Playback.apply(Playback.resolve(stream, videoId: videoId), action: action, to: player)
    }

    private func seekToChapter(_ chapter: Chapter) {
        let resolved = Playback.resolve(stream, videoId: videoId)
        player.registerChapters(resolved.chapters, for: videoId)
        player.jumpTo(videoId: videoId, url: resolved.url, audioUrl: resolved.audioUrl, title: resolved.title, artist: resolved.artist, thumbnail: resolved.thumbnail, duration: resolved.duration, startAt: Double(chapter.start))
    }
}
