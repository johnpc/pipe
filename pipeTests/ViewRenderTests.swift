import XCTest
import SwiftUI
@testable import pipe

/// Renders every SwiftUI view through UIHostingController to exercise their
/// `body` for coverage. Views are pure rendering, so instantiating + laying
/// out is sufficient to cover their declarative bodies.
@MainActor
final class ViewRenderTests: XCTestCase {

    private func render<V: View>(_ view: V) {
        let hc = UIHostingController(rootView: view)
        hc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        _ = hc.view.intrinsicContentSize
        hc.beginAppearanceTransition(true, animated: false)
        hc.endAppearanceTransition()
        hc.view.setNeedsLayout()
        hc.view.layoutIfNeeded()
    }

    /// Render a view into a real key window and pump the run loop so SwiftUI
    /// `.task { }` modifiers actually fire. Used to cover the "loaded" branch of
    /// views that fetch data on appear. Returns after `seconds` of pumping.
    private func renderLive<V: View>(_ view: V, seconds: TimeInterval = 1.5) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let hc = UIHostingController(rootView: view)
        window.rootViewController = hc
        window.isHidden = false
        window.makeKeyAndVisible()
        hc.view.setNeedsLayout()
        hc.view.layoutIfNeeded()
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        window.isHidden = true
        window.rootViewController = nil
    }

    // MARK: - Fixtures

    private func makeStores() -> (PlayerState, FollowingStore, RecentsStore) {
        let suite = UserDefaults(suiteName: "render-\(UUID().uuidString)")!
        return (PlayerState(defaults: suite), FollowingStore(defaults: suite), RecentsStore(defaults: suite))
    }

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "render-settings-\(UUID().uuidString)")!)
    }

    private func makeSaved() -> SavedStore {
        SavedStore(defaults: UserDefaults(suiteName: "render-saved-\(UUID().uuidString)")!)
    }

    private func makeDownloads() -> DownloadStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("render-dl-\(UUID().uuidString)", isDirectory: true)
        return DownloadStore(defaults: UserDefaults(suiteName: "render-dl-\(UUID().uuidString)")!, directory: dir) { _, dest, _ in
            try Data("m".utf8).write(to: dest)
        }
    }

    private func searchVideo() -> SearchItem {
        SearchItem(url: "/watch?v=v1", type: "stream", title: "Video", thumbnail: "t", uploaderName: "U", uploaderUrl: "/channel/c1", duration: 120, name: nil, uploadedDate: "1 day ago", verified: nil, subscribers: nil, videos: nil)
    }

    private func searchChannel() -> SearchItem {
        SearchItem(url: "/channel/c1", type: "channel", title: nil, thumbnail: "t", uploaderName: nil, uploaderUrl: nil, duration: nil, name: "Chan", uploadedDate: nil, verified: nil, subscribers: nil, videos: nil)
    }

    private func relatedStream() -> RelatedStream {
        RelatedStream(url: "/watch?v=v1", title: "Vid", thumbnail: "t", duration: 90, uploaderName: "U", uploadedDate: "2 days ago", uploaded: 100)
    }

    // MARK: - Root + tab bar

    func testRenderContentView() { render(ContentView()) }
    func testRenderTabButton() { render(TabButton(icon: "clock", label: "Recents", isSelected: true) {}) }

    // MARK: - Feed / Search / Recents / Following

    func testRenderFeedView() {
        let (p, f, r) = makeStores()
        render(NavigationStack { FeedView(player: p, following: f, recents: r, saved: makeSaved(), downloads: makeDownloads(), cache: FeedCache(defaults: UserDefaults(suiteName: "render-feed-\(UUID().uuidString)")!)) })
    }

    func testRenderContinueListeningShelf() {
        let (_, _, r) = makeStores()
        r.add(videoId: "a", title: "In Progress", artist: "A", thumbnail: "t", timestamp: 50, duration: 100)
        render(ContinueListeningShelf(recents: r) { _ in })
    }

    func testRenderContinueListeningShelfEmpty() {
        let (_, _, r) = makeStores()
        render(ContinueListeningShelf(recents: r) { _ in })
    }

    func testRenderSearchViewEmptyState() {
        let (p, f, r) = makeStores()
        render(NavigationStack { SearchView(player: p, following: f, recents: r, settings: makeSettings(), saved: makeSaved(), downloads: makeDownloads()) })
    }

    func testRenderSearchSuggestionsView() {
        render(SearchSuggestionsView(query: .constant(""), suggestions: SearchLogic.suggestions, onSearch: { _ in }))
    }

    func testRenderSearchSuggestionsViewWithHistory() {
        render(SearchSuggestionsView(query: .constant(""), suggestions: SearchLogic.suggestions, history: ["jazz", "lofi"], onSearch: { _ in }))
    }

    func testRenderSettingsView() {
        let (p, _, r) = makeStores()
        render(NavigationStack { SettingsView(settings: makeSettings(), player: p, recents: r) })
    }

    func testRenderSettingsViewWithActiveSleepTimerAndHistory() {
        let (p, _, r) = makeStores()
        p.startSleepTimer(minutes: 30)
        r.add(videoId: "w", title: "Watched", artist: "A", thumbnail: "", timestamp: 5, duration: 10)
        let s = makeSettings()
        s.recordSearch("history item")
        render(NavigationStack { SettingsView(settings: s, player: p, recents: r) })
    }

    func testRenderSavedViewEmpty() {
        let (p, _, _) = makeStores()
        render(NavigationStack { SavedView(player: p, saved: makeSaved()) })
    }

    func testRenderSavedViewWithItems() {
        let (p, _, _) = makeStores()
        let s = makeSaved()
        s.add(SavedItem(videoId: "v1", title: "Saved One", artist: "A", thumbnail: "t", duration: 60))
        render(NavigationStack { SavedView(player: p, saved: s) })
    }

    func testRenderDownloadsViewEmpty() {
        let (p, _, _) = makeStores()
        render(NavigationStack { DownloadsView(player: p, downloads: makeDownloads()) })
    }

    func testRenderDownloadsViewWithItems() async {
        let (p, _, _) = makeStores()
        let d = makeDownloads()
        await d.download(videoId: "v1", title: "Downloaded One", artist: "A", thumbnail: "t", duration: 60, audioUrl: "https://x/a", videoUrl: "")
        render(NavigationStack { DownloadsView(player: p, downloads: d) })
    }

    func testRenderDownloadButton() {
        let d = makeDownloads()
        let stream = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 10, hls: nil, audioStreams: [], videoStreams: [], thumbnailUrl: "t", uploadDate: nil, chapters: nil, relatedStreams: nil)
        render(DownloadButton(videoId: "v1", stream: stream, downloads: d))
    }

    func testRenderRecentsViewEmpty() {
        let (p, _, r) = makeStores()
        render(NavigationStack { RecentsView(player: p, recents: r) })
    }

    func testRenderRecentsViewWithItems() {
        let (p, _, r) = makeStores()
        r.add(videoId: "a", title: "Title", artist: "Artist", thumbnail: "t", timestamp: 30, duration: 100, uploadedDate: "1 day ago")
        render(NavigationStack { RecentsView(player: p, recents: r) })
    }

    func testRenderFollowingViewEmpty() {
        let (p, f, r) = makeStores()
        render(NavigationStack { FollowingView(player: p, following: f, recents: r) })
    }

    func testRenderFollowingViewWithChannels() {
        let (p, f, r) = makeStores()
        f.follow(FollowedChannel(id: "c1", name: "Chan", thumbnail: "t"))
        render(NavigationStack { FollowingView(player: p, following: f, recents: r) })
    }

    func testRenderChannelView() {
        let (p, f, r) = makeStores()
        render(NavigationStack { ChannelView(channelId: "c1", player: p, following: f, recents: r) })
    }

    func testRenderDetailView() {
        let (p, _, _) = makeStores()
        render(NavigationStack { DetailView(videoId: "v1", player: p) })
    }

    func testRenderRelatedVideosView() {
        let (p, _, _) = makeStores()
        render(RelatedVideosView(related: [relatedStream(), relatedStream()], player: p))
    }

    func testRenderTrendingView() {
        let (p, _, _) = makeStores()
        render(NavigationStack { TrendingView(player: p) })
    }

    func testRenderFeedDestinationRoutes() {
        let (p, _, _) = makeStores()
        for dest in ["downloads", "trending", "saved"] {
            render(NavigationStack { FeedDestination(dest: dest, player: p, saved: makeSaved(), downloads: makeDownloads()) })
        }
    }

    func testRenderCommentsView() {
        render(CommentsView(videoId: "v1"))
    }

    // MARK: - Playlists

    private func playlistItem() -> PlaylistItem {
        PlaylistItem(url: "/playlist?list=PL1", name: "Best Mix", thumbnail: "t", uploaderName: "U", videos: 12)
    }

    func testRenderPlaylistRow() {
        render(PlaylistRow(item: playlistItem()))
        // Nil-count, nil-uploader variant covers the optional branches.
        render(PlaylistRow(item: PlaylistItem(url: "/playlist?list=PL2", name: nil, thumbnail: nil, uploaderName: nil, videos: nil)))
    }

    func testRenderPlaylistHeaderVariants() {
        let pl = PlaylistResponse(name: "Best Mix", thumbnailUrl: "t", uploader: "U", relatedStreams: [relatedStream()])
        render(PlaylistHeader(playlist: pl, isSaved: false, onPlayAll: {}, onToggleSave: {}))
        render(PlaylistHeader(playlist: pl, isSaved: true, onPlayAll: {}, onToggleSave: {}))
    }

    func testRenderPlaylistView() {
        let (p, _, _) = makeStores()
        render(NavigationStack { PlaylistView(playlistId: "PL1", title: "Mix", player: p, saved: makeSavedPlaylists()) })
    }

    func testRenderChannelPlaylistsTab() {
        let (p, _, _) = makeStores()
        render(NavigationStack { ChannelPlaylistsTab(playlists: [playlistItem(), playlistItem()], player: p) })
        render(NavigationStack { ChannelPlaylistsTab(playlists: [], player: p) })
    }

    func testRenderSavedPlaylistsView() {
        let (p, _, _) = makeStores()
        let store = makeSavedPlaylists()
        render(NavigationStack { SavedPlaylistsView(player: p, saved: store) })
        store.add(SavedPlaylist(playlistId: "PL1", name: "Mix", thumbnail: "t", uploader: "U"))
        render(NavigationStack { SavedPlaylistsView(player: p, saved: store) })
    }

    private func makeSavedPlaylists() -> SavedPlaylistsStore {
        SavedPlaylistsStore(defaults: UserDefaults(suiteName: "render-savedpl-\(UUID().uuidString)")!)
    }

    func testRenderSearchResultRowAllTypes() {
        let (p, f, r) = makeStores()
        let noop = SearchRowActions(play: { _ in }, queue: { _ in }, playNext: { _ in }, toggleSave: { _ in }, toggleDownload: { _ in })
        func row(_ item: SearchItem) -> some View {
            NavigationStack { SearchResultRow(item: item, player: p, following: f, recents: r, saved: makeSaved(), downloads: makeDownloads(), onToggleFollow: {}, actions: noop) }
        }
        let playlist = SearchItem(url: "/playlist?list=PL1", type: "playlist", title: nil, thumbnail: "t", uploaderName: "U", uploaderUrl: nil, duration: nil, name: "Mix", uploadedDate: nil, verified: nil, subscribers: nil, videos: 4)
        render(row(searchVideo()))
        render(row(searchChannel()))
        render(row(playlist))
    }

    func testRenderSearchDestinationRoutes() {
        let (p, f, r) = makeStores()
        let playlist = SearchItem(url: "/playlist?list=PL1", type: "playlist", title: nil, thumbnail: "t", uploaderName: "U", uploaderUrl: nil, duration: nil, name: "Mix", uploadedDate: nil, verified: nil, subscribers: nil, videos: 4)
        for item in [searchVideo(), searchChannel(), playlist] {
            render(NavigationStack { SearchDestination(item: item, player: p, following: f, recents: r) })
        }
    }

    func testRenderCommentRowVariants() {
        // Verified + pinned + likes, and the plain variant — covers the branches.
        render(CommentRow(comment: Comment(commentId: "c1", author: "@me", commentText: "Nice", thumbnail: nil, likeCount: 3, commentedTime: "1d", verified: true, pinned: true)))
        render(CommentRow(comment: Comment(commentId: "c2", author: "@you", commentText: "Plain", thumbnail: nil, likeCount: nil, commentedTime: nil, verified: false, pinned: false)))
    }

    func testRenderChaptersView() {
        let chapters = [
            Chapter(title: "Intro", start: 0, image: nil),
            Chapter(title: "Deep Dive", start: 90, image: nil),
            Chapter(title: "Wrap Up", start: 240, image: nil),
        ]
        render(ChaptersView(chapters: chapters) { _ in })
    }

    /// Drives ChannelView's `.task` loader with a stubbed channel response so the
    /// loaded body (tab pills + video list) renders, not just the spinner.
    func testRenderChannelViewLoaded() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"id":"c1","name":"Chan","avatarUrl":"a","description":"d","relatedStreams":[{"url":"/watch?v=v1","title":"S1","thumbnail":"t","duration":61,"uploaderName":"U","uploadedDate":"1 day ago","uploaded":1}],"tabs":[{"name":"playlists","data":"tok"}]}
        """)
        let (p, f, r) = makeStores()
        f.follow(FollowedChannel(id: "c1", name: "Chan", thumbnail: "t"))
        renderLive(NavigationStack { ChannelView(channelId: "c1", player: p, following: f, recents: r) })
    }

    /// Drives DetailView's `.task` loader with a stubbed stream so the loaded
    /// body (thumbnail, play/queue buttons, description) renders.
    func testRenderDetailViewLoaded() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"title":"T","description":"<b>Hi</b>","uploader":"U","uploaderUrl":null,"duration":120,"hls":null,"audioStreams":[],"videoStreams":[{"url":"https://x/f.mp4","quality":"360p","mimeType":"video/mp4","videoOnly":false}],"thumbnailUrl":"th","uploadDate":"2026-01-01"}
        """)
        let (p, _, _) = makeStores()
        renderLive(NavigationStack { DetailView(videoId: "v1", player: p) })
    }

    /// Drives PlaylistView's loader with a stubbed playlist so the loaded body
    /// (header + Play All + video rows) renders, not just the spinner.
    func testRenderPlaylistViewLoaded() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"name":"Mix","thumbnailUrl":"t","uploader":"U","relatedStreams":[{"url":"/watch?v=p1","title":"One","thumbnail":"t","duration":30,"uploaderName":"U","uploadedDate":"1 day ago","uploaded":1}]}
        """)
        let (p, _, _) = makeStores()
        renderLive(NavigationStack { PlaylistView(playlistId: "PL1", title: "Mix", player: p, saved: makeSavedPlaylists()) })
    }

    /// Drives FeedView's loader with a followed channel + stubbed streams.
    func testRenderFeedViewLoaded() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"id":"c1","name":"Chan","avatarUrl":"a","description":"d","relatedStreams":[{"url":"/watch?v=v1","title":"S1","thumbnail":"t","duration":61,"uploaderName":"U","uploadedDate":"1 day ago","uploaded":5}],"tabs":null}
        """)
        let (p, f, r) = makeStores()
        f.follow(FollowedChannel(id: "c1", name: "Chan", thumbnail: "t"))
        renderLive(NavigationStack { FeedView(player: p, following: f, recents: r, saved: makeSaved(), downloads: makeDownloads(), cache: FeedCache(defaults: UserDefaults(suiteName: "render-feed-\(UUID().uuidString)")!)) })
    }


    // MARK: - Rows / components

    func testRenderVideoRow() {
        render(VideoRow(v: relatedStream(), isCompleted: true, resumeTime: 30, onPlay: {}, onQueue: {}))
        render(VideoRow(v: relatedStream(), isCompleted: false, resumeTime: nil, onPlay: {}, onQueue: {}))
    }

    func testRenderTabPill() {
        render(TabPill(title: "Videos", isSelected: true) {})
        render(TabPill(title: "Playlists", isSelected: false) {})
    }

    func testRenderAudioRow() {
        render(AudioRow(item: searchVideo(), isCompleted: true, resumeTime: 12, onPlay: {}, onQueue: {}))
        render(AudioRow(item: searchVideo()))
    }

    func testRenderChannelRow() { render(ChannelRow(item: searchChannel())) }

    func testRenderChannelRowVerifiedWithSubscribers() {
        let item = SearchItem(url: "/channel/c1", type: "channel", title: nil, thumbnail: "t", uploaderName: nil, uploaderUrl: nil, duration: nil, name: "Big Chan", uploadedDate: nil, verified: true, subscribers: 505_000_000, videos: nil)
        render(ChannelRow(item: item))
    }

    // MARK: - Player

    func testRenderMiniPlayerBar() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "Artist", thumbnail: "t", duration: 100)
        render(MiniPlayerBar(player: p))
    }

    func testRenderFullPlayerSheet() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "Artist", thumbnail: "t", duration: 100)
        p.addToQueue(videoId: "v2", url: "bad://v2", title: "Next", artist: "A", thumbnail: "t", duration: 60)
        render(FullPlayerSheet(player: p))
    }

    func testRenderFullPlayerSheetVideoMode() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "Artist", thumbnail: "t", duration: 100)
        p.videoMode = true
        render(FullPlayerSheet(player: p))
    }

    func testRenderFullPlayerSheetWithChapterLabel() {
        let (p, _, _) = makeStores()
        p.registerChapters([Chapter(title: "Intro", start: 0, image: nil), Chapter(title: "Part 2", start: 60, image: nil)], for: "v")
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "Artist", thumbnail: "t", duration: 100)
        render(FullPlayerSheet(player: p))
    }

    func testRenderQueueSection() {
        let (p, _, _) = makeStores()
        p.addToQueue(videoId: "v1", url: "bad://1", title: "One", artist: "A", thumbnail: "t", duration: 10)
        p.addToQueue(videoId: "v2", url: "bad://2", title: "Two", artist: "A", thumbnail: "t", duration: 20)
        render(QueueSection(player: p))
    }

    func testRenderQueueRow() {
        let (p, _, _) = makeStores()
        p.addToQueue(videoId: "v1", url: "bad://1", title: "One", artist: "A", thumbnail: "t", duration: 10)
        render(QueueRow(player: p, item: p.queue[0], index: 0))
        p.addToQueue(videoId: "v2", url: "bad://2", title: "Two", artist: "A", thumbnail: "t", duration: 0)
        render(QueueRow(player: p, item: p.queue[1], index: 1))
    }

    func testRenderVideoPlayerView() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "S", artist: "A", thumbnail: "t", duration: 10)
        render(VideoPlayerView(player: p))
    }

    func testRenderPiPVideoPlayer() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "S", artist: "A", thumbnail: "t", duration: 10)
        if let avPlayer = p.player {
            render(PiPVideoPlayer(player: avPlayer))
        }
    }

    // MARK: - Toast

    func testRenderToastView() {
        render(ToastView(message: "Loading...", isLoading: true))
        render(ToastView(message: "Done", isLoading: false))
    }
}
