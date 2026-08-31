import XCTest
import SwiftUI
@testable import pipe

/// Summarizer double for driving TranscriptTab's loaded/summary render paths.
@MainActor
private final class RenderMockSummarizer: Summarizing {
    let isAvailable: Bool
    let snapshots: [String]
    init(available: Bool, snapshots: [String] = []) {
        self.isAvailable = available
        self.snapshots = snapshots
    }
    func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for s in snapshots { c.yield(s) }
            c.finish()
        }
    }
}

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

    // MARK: - Offline mode

    func testRenderOfflinePlaceholder() { render(OfflinePlaceholderView()) }

    func testRenderMainTabContentOnlineAndOffline() {
        let (p, f, r) = makeStores()
        func content(tab: Int, offline: Bool) -> some View {
            let s = makeSettings(); s.offlineMode = offline
            return MainTabContent(selectedTab: tab, player: p, following: f, recents: r, settings: s, saved: makeSaved(), downloads: makeDownloads())
        }
        // Online: each tab renders its screen.
        for tab in 0...3 { render(content(tab: tab, offline: false)) }
        // Offline: Feed→Downloads, Search→placeholder, Recents/Following unchanged.
        for tab in 0...3 { render(content(tab: tab, offline: true)) }
    }

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

    func testRenderCastQualitySection() {
        let s = makeSettings()
        // Render each selection so the picker's rows are all exercised.
        for q in CastQuality.allCases {
            s.castQuality = q
            render(NavigationStack { Form { CastQualitySection(settings: s) } })
        }
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

    /// Live-render with several rows so the List actually lays out its cells —
    /// exercising the duration/resume/uploaded-date branches and the row actions
    /// that a static render leaves uncovered.
    func testRenderRecentsViewRowsLive() {
        let (p, _, r) = makeStores()
        r.add(videoId: "a", title: "Resumable", artist: "Artist", thumbnail: "t", timestamp: 45, duration: 200, uploadedDate: "2 days ago")
        r.add(videoId: "b", title: "No Duration", artist: "B", thumbnail: "t", timestamp: 0, duration: 0, uploadedDate: nil)
        renderLive(NavigationStack { RecentsView(player: p, recents: r) }, seconds: 0.6)
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

    func testRenderCommentsList() {
        render(NavigationStack { CommentsList(videoId: "v1") })
    }

    /// Regression: the Comments tab crashed on every real video because an
    /// unbounded `List` (a scroll container) was nested inside the Full Player's
    /// vertical `ScrollView`, which offers it infinite height. Reproduce by
    /// loading real comments into the exact embedding the player uses.
    func testRenderCommentsListLoadedInScrollView() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"disabled":false,"comments":[{"commentId":"c1","author":"@a","commentText":"Great video <b>thanks</b>","thumbnail":null,"likeCount":12,"commentedTime":"1d","verified":true,"pinned":true},{"commentId":"c2","author":"@b","commentText":"Plain comment","thumbnail":null,"likeCount":null,"commentedTime":"2d","verified":false,"pinned":false}]}
        """)
        renderLive(ScrollView { CommentsList(videoId: "v1").frame(minHeight: 300) })
    }

    // MARK: - Full-player tabs

    private func streamWithExtras() -> StreamResponse {
        StreamResponse(title: "T", description: "Intro 1:23 jump", uploader: "U", uploaderUrl: nil, duration: 100, hls: nil, audioStreams: [], videoStreams: [], thumbnailUrl: "t", uploadDate: nil,
                       chapters: [Chapter(title: "Intro", start: 0, image: nil), Chapter(title: "Part 2", start: 60, image: nil)],
                       relatedStreams: [relatedStream(), relatedStream()])
    }

    func testRenderPlayerInfoTab() {
        let (p, _, _) = makeStores()
        render(PlayerInfoTab(stream: streamWithExtras(), player: p))
        // Empty variant (no chapters, no description) shows the unavailable state.
        let empty = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 1, hls: nil, audioStreams: [], videoStreams: [], thumbnailUrl: "t", uploadDate: nil, chapters: nil, relatedStreams: nil)
        render(PlayerInfoTab(stream: empty, player: p))
    }

    func testRenderPlayerTabsView() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "A", thumbnail: "t", duration: 100)
        p.addToQueue(videoId: "v2", url: "bad://2", title: "Next", artist: "A", thumbnail: "t", duration: 60)
        render(NavigationStack { PlayerTabsView(player: p, detail: NowPlayingDetail()) })
    }

    func testRenderTranscriptTabEmpty() {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "A", thumbnail: "t", duration: 100)
        // No subtitles + unavailable summarizer → failed state, no button.
        let store = TranscriptStore(summarizer: RenderMockSummarizer(available: false)) { _ in "" }
        render(NavigationStack { TranscriptTab(player: p, detail: NowPlayingDetail(), store: store) })
    }

    func testRenderTranscriptTabLoadedWithSummary() async {
        let (p, _, _) = makeStores()
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "A", thumbnail: "t", duration: 100)
        let mock = RenderMockSummarizer(available: true, snapshots: ["Key points:", "Key points: a, b"])
        let store = TranscriptStore(summarizer: mock) { _ in
            "<tt><body><div><p begin=\"00:00:01.000\">hello</p></div></body></tt>"
        }
        let subs = [Subtitle(url: "https://x/en.ttml", name: "English", code: "en", autoGenerated: false)]
        await store.load(subtitles: subs, videoId: "v")
        store.summarize()
        var elapsed: UInt64 = 0
        while store.isSummarizing && elapsed < 2_000_000_000 {
            try? await Task.sleep(nanoseconds: 20_000_000); elapsed += 20_000_000
        }
        render(NavigationStack { TranscriptTab(player: p, detail: NowPlayingDetail(), store: store) })
    }

    func testRenderToastOverlay() {
        ToastManager.shared.showSuccess("Added to Queue")
        render(Color.clear.toastOverlay())
        ToastManager.shared.hide()
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
        let noop = SearchRowActions(play: { _ in }, queue: { _ in }, playNext: { _ in }, cast: { _ in }, toggleSave: { _ in }, toggleDownload: { _ in })
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

    func testRenderCastButton() {
        // Devices available → active (accent) glyph.
        render(CastButton(cast: CastStore(caster: MockCaster(isAvailable: true))))
        // No devices → dimmed glyph + the "Search Again" dialog path.
        render(CastButton(cast: CastStore(caster: MockCaster(isAvailable: false))))
    }

    /// Regression: the no-devices state once used the SF Symbol
    /// "tv.badge.wifi.searchlight", which does not exist — SwiftUI renders a blank
    /// image for an unknown symbol, so the whole cast button became invisible.
    /// Assert every symbol the button can use actually resolves.
    func testCastButtonSymbolsExist() {
        for name in ["tv.badge.wifi"] {
            XCTAssertNotNil(UIImage(systemName: name), "SF Symbol \(name) must exist or the cast button renders blank")
        }
    }

    func testRenderFullPlayerSheetWithCast() {
        let (p, _, _) = makeStores()
        p.cast = CastStore(caster: MockCaster())
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "Artist", thumbnail: "t", duration: 100)
        render(FullPlayerSheet(player: p))
    }

    /// Regression: the cast button shipped as an embedded UIKit `GCKUICastButton`,
    /// which crashed when the full player was shown via `.sheet` on iOS 26
    /// (SwiftUI's remote-sheet presentation fatal-cast). Present the sheet for
    /// real (not just render the content) so a UIKit-in-sheet regression trips
    /// here instead of in production.
    func testPresentFullPlayerAsSheetWithCastDoesNotCrash() {
        let (p, _, _) = makeStores()
        p.cast = CastStore(caster: MockCaster())
        p.play(videoId: "v", urlString: "bad://v", title: "Song", artist: "A", thumbnail: "t", duration: 100)
        struct Host: View {
            @ObservedObject var player: PlayerState
            var body: some View {
                Color.clear.sheet(isPresented: .constant(true)) { FullPlayerSheet(player: player) }
            }
        }
        renderLive(Host(player: p), seconds: 1.0)
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
