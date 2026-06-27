import SwiftUI

/// The paginated video list for a channel's main "Videos" tab. Owns the
/// load-more paging so ChannelView stays thin and under the line limit.
struct ChannelVideoList: View {
    let channelId: String
    @ObservedObject var player: PlayerState
    @ObservedObject var recents: RecentsStore
    @State var videos: [RelatedStream]
    @State var nextpage: String?
    @State private var loadingMore = false

    var body: some View {
        List {
            ForEach(videos) { v in
                NavigationLink(value: v) {
                    VideoRow(v: v, isCompleted: recents.isCompleted(videoId: v.videoId), resumeTime: recents.resumeTime(videoId: v.videoId), onPlay: { play(v, .play) }, onQueue: { play(v, .queue) })
                }
            }
            if Pagination.hasMore(nextpage) {
                loadMoreRow
            }
        }
        .listStyle(.plain)
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if loadingMore { ProgressView() } else {
                Button("Load More") { Task { await loadMore() } }
                    .accessibilityIdentifier("loadMoreButton")
            }
            Spacer()
        }
        .onAppear { Task { await loadMore() } }
    }

    private func loadMore() async {
        guard !loadingMore, let token = nextpage else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let page = try? await PipedAPI.channelNextPage(channelId: channelId, nextpage: token) {
            videos = Pagination.merge(videos, page.content)
            nextpage = page.nextpage
        } else {
            nextpage = nil // stop trying on failure
        }
    }

    private func play(_ v: RelatedStream, _ action: Playback.Action) {
        Task { await Playback.run(videoId: v.videoId, action: action, player: player) }
    }
}
