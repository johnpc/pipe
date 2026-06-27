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

    private func searchVideo() -> SearchItem {
        SearchItem(url: "/watch?v=v1", type: "stream", title: "Video", thumbnail: "t", uploaderName: "U", uploaderUrl: "/channel/c1", duration: 120, name: nil, uploadedDate: "1 day ago")
    }

    private func searchChannel() -> SearchItem {
        SearchItem(url: "/channel/c1", type: "channel", title: nil, thumbnail: "t", uploaderName: nil, uploaderUrl: nil, duration: nil, name: "Chan", uploadedDate: nil)
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
        render(NavigationStack { FeedView(player: p, following: f, recents: r, saved: makeSaved(), cache: FeedCache(defaults: UserDefaults(suiteName: "render-feed-\(UUID().uuidString)")!)) })
    }

    func testRenderSearchViewEmptyState() {
        let (p, f, r) = makeStores()
        render(NavigationStack { SearchView(player: p, following: f, recents: r, settings: makeSettings(), saved: makeSaved()) })
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

    /// Drives FeedView's loader with a followed channel + stubbed streams.
    func testRenderFeedViewLoaded() {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: """
        {"id":"c1","name":"Chan","avatarUrl":"a","description":"d","relatedStreams":[{"url":"/watch?v=v1","title":"S1","thumbnail":"t","duration":61,"uploaderName":"U","uploadedDate":"1 day ago","uploaded":5}],"tabs":null}
        """)
        let (p, f, r) = makeStores()
        f.follow(FollowedChannel(id: "c1", name: "Chan", thumbnail: "t"))
        renderLive(NavigationStack { FeedView(player: p, following: f, recents: r, saved: makeSaved(), cache: FeedCache(defaults: UserDefaults(suiteName: "render-feed-\(UUID().uuidString)")!)) })
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

    // MARK: - Toast

    func testRenderToastView() {
        render(ToastView(message: "Loading...", isLoading: true))
        render(ToastView(message: "Done", isLoading: false))
    }
}
