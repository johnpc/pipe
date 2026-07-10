import SwiftUI

struct ChannelView: View {
    let channelId: String
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @State var channel: ChannelResponse?
    @State var failed = false
    @State private var selectedTab = "videos"
    @State var tabContent: [RelatedStream] = []
    @State var tabPlaylists: [PlaylistItem] = []
    @State var loadingTab = false

    var body: some View {
        Group {
            if let ch = channel {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TabPill(title: "Videos", isSelected: selectedTab == "videos") {
                                selectedTab = "videos"
                            }
                            if let tabs = ch.tabs {
                                ForEach(tabs, id: \.name) { tab in
                                    TabPill(title: tab.name.capitalized, isSelected: selectedTab == tab.name) {
                                        selectedTab = tab.name
                                        loadTab(tab.name, data: tab.data)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }

                    if loadingTab {
                        Spacer(); ProgressView(); Spacer()
                    } else if selectedTab == "videos" {
                        // Paginated main videos list.
                        ChannelVideoList(channelId: channelId, player: player, recents: recents, videos: ch.relatedStreams, nextpage: ch.nextpage)
                            .id(ch.id)
                    } else if selectedTab == "playlists" {
                        ChannelPlaylistsTab(playlists: tabPlaylists, player: player)
                    } else {
                        List(tabContent) { v in
                            NavigationLink(value: v) {
                                VideoRow(v: v, isCompleted: recents.isCompleted(videoId: v.videoId), resumeTime: recents.resumeTime(videoId: v.videoId), onPlay: { play(v, .play) }, onQueue: { play(v, .queue) }, onCast: { Playback.cast(videoId: v.videoId, player: player) })
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
                .navigationTitle(ch.name)
                .toolbar { followButton(ch) }
            } else if failed {
                RetryView { Task { await load() } }
            } else { ProgressView() }
        }
        .task { await load() }
    }

    private func followButton(_ ch: ChannelResponse) -> some View {
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

    private func play(_ v: RelatedStream, _ action: Playback.Action) {
        Task { await Playback.run(videoId: v.videoId, action: action, player: player) }
    }
}
