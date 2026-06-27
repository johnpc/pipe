import SwiftUI

struct FeedView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @State private var videos: [RelatedStream] = []
    @State private var loading = false
    
    var body: some View {
        Group {
            if loading {
                ProgressView("Loading feed...")
            } else if videos.isEmpty {
                ContentUnavailableView("No Feed", systemImage: "rectangle.stack", description: Text("Follow channels to see their videos here"))
            } else {
                List(videos) { v in
                    VideoRow(v: v, isCompleted: recents.isCompleted(videoId: v.videoId), resumeTime: recents.resumeTime(videoId: v.videoId), onPlay: { playVideo(v) }, onQueue: { queueVideo(v) })
                }
                .listStyle(.plain)
                .refreshable { await loadFeed() }
            }
        }
        .navigationTitle("Feed")
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
        
        // Sort by upload timestamp (most recent first)
        videos = allVideos.sorted { ($0.uploaded ?? 0) > ($1.uploaded ?? 0) }
        loading = false
    }
    
    private func playVideo(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .play, player: player) }
    }

    private func queueVideo(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .queue, player: player) }
    }
}
