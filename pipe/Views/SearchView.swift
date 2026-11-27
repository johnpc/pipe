import SwiftUI
struct SearchView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var saved: SavedStore
    @ObservedObject var downloads: DownloadStore
    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var filter: SearchFilter = .all
    @State private var loading = false
    @State private var suggestions: [String] = []
    var body: some View {
        VStack(spacing: 0) {
            if SearchLogic.isSubmittable(query) {
                SearchFilterBar(filter: $filter)
            }
            if results.isEmpty && !loading {
                SearchSuggestionsView(query: $query, suggestions: suggestions, history: settings.searchHistory, onSearch: search)
            } else {
                List(filter.apply(results)) { item in
                    SearchResultRow(item: item, player: player, following: following, recents: recents,
                                    saved: saved, downloads: downloads,
                                    onToggleFollow: { toggleFollow(item) }, actions: rowActions)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: SearchItem.self) { item in
            SearchDestination(item: item, player: player, following: following, recents: recents)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .onSubmit(of: .search) { search(query) }
        .task(id: query) { await autoSearch(query) }
        .task(id: settings.instanceURL) { suggestions = await SearchLogic.loadChannelSuggestions() }
        .onChange(of: query) { _, q in if q.isEmpty { results = [] } }
        .onChange(of: filter) { _, _ in Task { await refetch() } }  // the instance filters server-side too
        .overlay { if loading { ProgressView() } }
    }
    /// Debounced search-as-you-type (history is recorded only on explicit submit).
    private func autoSearch(_ term: String) async {
        guard SearchLogic.shouldAutoSearch(term) else { return }
        try? await Task.sleep(nanoseconds: SearchLogic.autoSearchDebounceNanos)
        guard !Task.isCancelled else { return }  // superseded by a newer keystroke
        await refetch(term)
    }
    private func refetch(_ term: String? = nil) async {
        let term = term ?? query
        guard SearchLogic.isSubmittable(term) else { return }
        loading = true
        results = (try? await PipedAPI.search(term, filter: filter)) ?? []
        loading = false
    }
    private func search(_ term: String) {
        guard SearchLogic.isSubmittable(term) else { return }
        query = term
        settings.recordSearch(term)
        Task { await refetch(term) }
    }
    private var rowActions: SearchRowActions {
        SearchRowActions(play: playItem, queue: queueItem, playNext: playNextItem,
                         cast: castItem,
                         toggleSave: { saved.toggle(savedItem($0)) },
                         toggleDownload: toggleDownload)
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
        Playback.perform(QueueItem(pending: item), action: .queue, player: player)
    }
    private func playNextItem(_ item: SearchItem) {
        Playback.perform(QueueItem(pending: item), action: .playNext, player: player)
    }
    private func castItem(_ item: SearchItem) {
        Playback.cast(videoId: item.videoId, player: player)
    }
    private func savedItem(_ item: SearchItem) -> SavedItem {
        SavedItem(videoId: item.videoId, title: item.displayTitle, artist: item.displayUploader, thumbnail: item.displayThumbnail, duration: item.duration ?? 0)
    }
    private func toggleDownload(_ item: SearchItem) {
        Task {
            await DownloadCoordinator.toggle(videoId: item.videoId, title: item.displayTitle, artist: item.displayUploader, thumbnail: item.displayThumbnail, duration: item.duration ?? 0, downloads: downloads)
        }
    }
}
