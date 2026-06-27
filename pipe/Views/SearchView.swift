import SwiftUI

struct SearchView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var loading = false

    private let suggestions = SearchLogic.suggestions

    var body: some View {
        Group {
            if results.isEmpty && !loading {
                SearchSuggestionsView(query: $query, suggestions: suggestions, history: settings.searchHistory, onSearch: search)
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
                            AudioRow(item: item, isCompleted: recents.isCompleted(videoId: item.videoId), resumeTime: recents.resumeTime(videoId: item.videoId), onPlay: { playItem(item) }, onQueue: { queueItem(item) })
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: SearchItem.self) { item in
            if item.isChannel { ChannelView(channelId: item.channelId, player: player, following: following, recents: recents) }
            else { DetailView(videoId: item.videoId, player: player) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .onSubmit(of: .search) { search(query) }
        .overlay { if loading { ProgressView() } }
    }
    
    private func search(_ term: String) {
        guard SearchLogic.isSubmittable(term) else { return }
        query = term
        settings.recordSearch(term)
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
        Task { await Playback.run(videoId: item.videoId, action: .play, player: player) }
    }

    private func queueItem(_ item: SearchItem) {
        Task { await Playback.run(videoId: item.videoId, action: .queue, player: player) }
    }
}
