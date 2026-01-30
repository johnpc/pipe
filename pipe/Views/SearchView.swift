import SwiftUI

struct SearchView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var loading = false
    
    private let suggestions = [
        "Joe Rogan Experience",
        "Lex Fridman",
        "Huberman Lab",
        "MrBeast",
        "Veritasium",
        "Marques Brownlee",
        "Kurzgesagt",
        "3Blue1Brown"
    ]
    
    var body: some View {
        Group {
            if results.isEmpty && !loading {
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                        Text("Search YouTube")
                            .font(.title2)
                        Text("Try one of these popular channels")
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button { search(suggestion) } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                List(results) { item in
                    if item.isChannel {
                        HStack {
                            NavigationLink(value: item) { ChannelRow(item: item) }
                            Button { toggleFollow(item) } label: {
                                Image(systemName: following.isFollowing(item.channelId) ? "heart.fill" : "heart")
                                    .foregroundColor(following.isFollowing(item.channelId) ? .red : .gray)
                            }.buttonStyle(.plain)
                        }
                    } else {
                        NavigationLink(value: item) {
                            AudioRow(item: item, onPlay: { playItem(item) }, onQueue: { queueItem(item) })
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SearchItem.self) { item in
            if item.isChannel { ChannelView(channelId: item.channelId, player: player, following: following) }
            else { DetailView(videoId: item.videoId, player: player) }
        }
        .searchable(text: $query, prompt: "Search")
        .onSubmit(of: .search) { search(query) }
        .overlay { if loading { ProgressView() } }
    }
    
    private func search(_ term: String) {
        query = term
        loading = true
        Task { results = (try? await PipedAPI.search(term)) ?? []; loading = false }
    }
    
    private func toggleFollow(_ item: SearchItem) {
        if following.isFollowing(item.channelId) {
            following.unfollow(item.channelId)
        } else {
            following.follow(FollowedChannel(id: item.channelId, name: item.displayTitle, thumbnail: item.displayThumbnail))
        }
    }
    
    private func playItem(_ item: SearchItem) {
        ToastManager.shared.showLoading("Loading...")
        Task {
            guard let stream = try? await PipedAPI.streams(item.videoId) else {
                await MainActor.run { ToastManager.shared.hide() }
                return
            }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.play(videoId: item.videoId, urlString: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration, uploadedDate: stream.uploadDate)
                ToastManager.shared.showSuccess("Now Playing")
            }
        }
    }
    
    private func queueItem(_ item: SearchItem) {
        ToastManager.shared.showLoading("Adding...")
        Task {
            guard let stream = try? await PipedAPI.streams(item.videoId) else {
                await MainActor.run { ToastManager.shared.hide() }
                return
            }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.addToQueue(videoId: item.videoId, url: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration, uploadedDate: stream.uploadDate)
                ToastManager.shared.showSuccess("Added to Queue")
            }
        }
    }
}
