import SwiftUI

struct FeedView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var saved: SavedStore
    @ObservedObject var downloads: DownloadStore
    @State private var videos: [RelatedStream] = []
    @State private var loading = false
    @State private var sort: FeedSort = .newest
    @State private var hideWatched = false
    var cache = FeedCache()

    private var arranged: [RelatedStream] {
        FeedLogic.arrange(videos, sort: sort, hideWatched: hideWatched) {
            recents.isCompleted(videoId: $0.videoId)
        }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading feed...")
            } else if arranged.isEmpty {
                ContentUnavailableView("No Feed", systemImage: "rectangle.stack", description: Text("Follow channels to see their videos here"))
            } else {
                List(arranged) { v in
                    VideoRow(v: v, isCompleted: recents.isCompleted(videoId: v.videoId), resumeTime: recents.resumeTime(videoId: v.videoId), onPlay: { playVideo(v) }, onQueue: { queueVideo(v) }, isSaved: saved.isSaved(v.videoId), onToggleSave: { saved.toggle(savedItem(v)) })
                }
                .listStyle(.plain)
                .refreshable { await loadFeed() }
            }
        }
        .navigationTitle("Feed")
        .navigationDestination(for: String.self) { dest in
            if dest == "downloads" {
                DownloadsView(player: player, downloads: downloads)
            } else {
                SavedView(player: player, saved: saved)
            }
        }
        .toolbar { FeedToolbar(sort: $sort, hideWatched: $hideWatched) }
        .task { await loadFeed() }
        .onChange(of: following.channels) { _, _ in
            Task { await loadFeed() }
        }
    }

    private func loadFeed() async {
        guard !following.channels.isEmpty else {
            videos = []
            return
        }

        // Show cached videos instantly; only spin on a true cold load.
        if videos.isEmpty, let cached = cache.cachedVideos(), !cached.isEmpty {
            videos = cached
        }
        loading = videos.isEmpty

        var allVideos: [RelatedStream] = []
        await withTaskGroup(of: [RelatedStream].self) { group in
            for channel in following.channels {
                group.addTask {
                    (try? await PipedAPI.channel(channel.id).relatedStreams) ?? []
                }
            }
            for await streams in group {
                allVideos.append(contentsOf: streams)
            }
        }

        // Keep showing cached content if the network returned nothing.
        if allVideos.isEmpty {
            loading = false
            return
        }

        let sorted = allVideos.sorted { ($0.uploaded ?? 0) > ($1.uploaded ?? 0) }
        videos = sorted
        cache.save(sorted)
        loading = false
    }
    
    private func savedItem(_ v: RelatedStream) -> SavedItem {
        SavedItem(videoId: v.videoId, title: v.title, artist: v.uploaderName ?? "", thumbnail: v.thumbnail, duration: v.duration)
    }

    private func playVideo(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .play, player: player) }
    }

    private func queueVideo(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .queue, player: player) }
    }
}
