import SwiftUI

struct ChannelView: View {
    let channelId: String
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @State private var channel: ChannelResponse?
    @State private var selectedTab = "videos"
    @State private var tabContent: [RelatedStream] = []
    @State private var loadingTab = false
    
    var videos: [RelatedStream] {
        selectedTab == "videos" ? (channel?.relatedStreams ?? []) : tabContent
    }
    
    var body: some View {
        Group {
            if let ch = channel {
                VStack(spacing: 0) {
                    // Tab picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TabPill(title: "Videos", isSelected: selectedTab == "videos") {
                                selectedTab = "videos"
                            }
                            if let tabs = ch.tabs {
                                ForEach(tabs, id: \.name) { tab in
                                    TabPill(title: tab.name.capitalized, isSelected: selectedTab == tab.name) {
                                        selectedTab = tab.name
                                        loadTab(tab.data)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    if loadingTab {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else {
                        List(videos) { v in
                            NavigationLink(value: v) {
                                VideoRow(v: v, isCompleted: recents.isCompleted(videoId: v.videoId), resumeTime: recents.resumeTime(videoId: v.videoId), onPlay: { playVideo(v) }, onQueue: { queueVideo(v) })
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
                .navigationTitle(ch.name)
                .toolbar {
                    Button {
                        if following.isFollowing(channelId) {
                            following.unfollow(channelId)
                        } else {
                            following.follow(FollowedChannel(id: channelId, name: ch.name, thumbnail: ch.avatarUrl ?? ""))
                        }
                    } label: {
                        Image(systemName: following.isFollowing(channelId) ? "heart.fill" : "heart")
                            .foregroundColor(following.isFollowing(channelId) ? .red : .primary)
                    }
                }
            } else { ProgressView() }
        }
        .task { channel = try? await PipedAPI.channel(channelId) }
    }
    
    private func loadTab(_ data: String) {
        loadingTab = true
        Task {
            let response = try? await PipedAPI.channelTab(data)
            await MainActor.run {
                tabContent = response?.content ?? []
                loadingTab = false
            }
        }
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

struct TabPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct VideoRow: View {
    let v: RelatedStream
    var isCompleted: Bool = false
    var resumeTime: Double? = nil
    let onPlay: () -> Void
    let onQueue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: v.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 100, height: 56).clipped().cornerRadius(6)
                        .overlay(isCompleted ? Color.black.opacity(0.4).cornerRadius(6) : nil)
                    HStack(spacing: 4) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        if v.duration > 0 {
                            Text(formatDuration(v.duration))
                                .font(.caption2).bold()
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let uploader = v.uploaderName {
                        Text(uploader).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    }
                    if let date = v.uploadedDate {
                        Text(formatUploadDate(date)).font(.caption2).foregroundStyle(.tertiary)
                    }
                    if let time = resumeTime {
                        Label(formatTime(time), systemImage: "play.circle").font(.caption2).foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill").font(.title2)
                }.buttonStyle(.plain)
                Button(action: onQueue) {
                    Image(systemName: "text.badge.plus").font(.title3)
                }.buttonStyle(.plain)
            }
            
            Text(v.title).font(.subheadline).lineLimit(3)
        }
        .padding(.vertical, 8)
    }
}
