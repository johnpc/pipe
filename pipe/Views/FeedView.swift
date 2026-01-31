import SwiftUI

struct FeedView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
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
                    VideoRow(v: v, onPlay: { playVideo(v) }, onQueue: { queueVideo(v) })
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
        ToastManager.shared.showLoading("Loading...")
        Task {
            guard let stream = try? await PipedAPI.streams(v.videoId) else {
                await MainActor.run { ToastManager.shared.hide() }
                return
            }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.play(videoId: v.videoId, urlString: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration, uploadedDate: stream.uploadDate)
                ToastManager.shared.showSuccess("Now Playing")
            }
        }
    }
    
    private func queueVideo(_ v: RelatedStream) {
        ToastManager.shared.showLoading("Adding...")
        Task {
            guard let stream = try? await PipedAPI.streams(v.videoId) else {
                await MainActor.run { ToastManager.shared.hide() }
                return
            }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.addToQueue(videoId: v.videoId, url: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration, uploadedDate: stream.uploadDate)
                ToastManager.shared.showSuccess("Added to Queue")
            }
        }
    }
}
