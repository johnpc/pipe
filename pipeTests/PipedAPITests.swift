import Testing
import Foundation
@testable import pipe

/// Serialized: these tests mutate the shared `PipedAPI.session` and
/// `MockURLProtocol.requestHandler` statics, so they must not run in parallel.
@MainActor
@Suite(.serialized)
struct PipedAPITests {

    private func withStub(_ json: String, _ body: () async throws -> Void) async rethrows {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: json)
        defer { PipedAPI.session = .shared }
        try await body()
    }

    // MARK: - URL construction (pure)

    @Test func searchURLEncodesQuery() {
        let url = PipedAPI.searchURL("hello world")
        #expect(url.absoluteString.contains("q=hello%20world"))
        #expect(url.absoluteString.contains("filter=all"))
    }

    @Test func channelTabURLEncodesData() {
        let url = PipedAPI.channelTabURL("a b&c")
        #expect(url.absoluteString.contains("data="))
        #expect(!url.absoluteString.contains("a b&c"))
    }

    // MARK: - Decoding

    @Test func searchDecodesItems() async throws {
        let json = """
        {"items":[{"url":"/watch?v=abc","type":"stream","title":"Vid","thumbnail":"t","uploaderName":"U","uploaderUrl":"/channel/c1","duration":100,"name":null,"uploadedDate":"1 day ago"}]}
        """
        try await withStub(json) {
            let items = try await PipedAPI.search("x")
            #expect(items.count == 1)
            #expect(items[0].videoId == "abc")
            #expect(items[0].displayTitle == "Vid")
            #expect(items[0].isChannel == false)
        }
    }

    @Test func channelDecodes() async throws {
        let json = """
        {"id":"c1","name":"Chan","avatarUrl":"a","description":"d","relatedStreams":[{"url":"/watch?v=v1","title":"S1","thumbnail":"t","duration":60,"uploaderName":"U","uploadedDate":null,"uploaded":12345}],"tabs":[{"name":"playlists","data":"tok"}]}
        """
        try await withStub(json) {
            let ch = try await PipedAPI.channel("c1")
            #expect(ch.name == "Chan")
            #expect(ch.relatedStreams.count == 1)
            #expect(ch.relatedStreams[0].videoId == "v1")
            #expect(ch.tabs?.first?.name == "playlists")
        }
    }

    @Test func channelTabDecodes() async throws {
        let json = """
        {"content":[{"url":"/watch?v=v2","title":"S2","thumbnail":"t","duration":30,"uploaderName":null,"uploadedDate":null,"uploaded":null}],"nextpage":null}
        """
        try await withStub(json) {
            let tab = try await PipedAPI.channelTab("tok")
            #expect(tab.content.count == 1)
            #expect(tab.content[0].videoId == "v2")
        }
    }

    @Test func streamsDecodes() async throws {
        let json = """
        {"title":"T","description":"d","uploader":"U","uploaderUrl":null,"duration":200,"hls":null,"audioStreams":[{"url":"au","bitrate":128,"mimeType":"audio/mp4"}],"videoStreams":[{"url":"vu","quality":"720p","mimeType":"video/mp4","videoOnly":false}],"thumbnailUrl":"th","uploadDate":"2026-01-01"}
        """
        try await withStub(json) {
            let s = try await PipedAPI.streams("v")
            #expect(s.title == "T")
            #expect(s.duration == 200)
            #expect(s.audioStreams.count == 1)
            #expect(s.videoStreams[0].quality == "720p")
        }
    }

    @Test func searchThrowsOnBadJSON() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: "not json")
        defer { PipedAPI.session = .shared }
        await #expect(throws: (any Error).self) {
            _ = try await PipedAPI.search("x")
        }
    }

    // MARK: - Playback.run full flow (network-dependent, hence serialized here)

    private static let streamJSON = """
    {"title":"Song","description":null,"uploader":"Artist","uploaderUrl":null,"duration":120,"hls":null,"audioStreams":[],"videoStreams":[{"url":"https://x/full.mp4","quality":"360p","mimeType":"video/mp4","videoOnly":false}],"thumbnailUrl":"t","uploadDate":null}
    """

    @Test func runPlaySuccessShowsSuccessToast() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }

        let player = isolatedPlayer()
        let toast = SpyToast()
        await Playback.run(videoId: "vid", action: .play, player: player, toast: toast)

        #expect(toast.events.contains("loading:Loading..."))
        #expect(toast.events.contains("success:Now Playing"))
        #expect(player.queue.count == 1)
    }

    @Test func runQueueSuccessShowsAddedToast() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }

        let player = isolatedPlayer()
        let toast = SpyToast()
        await Playback.run(videoId: "vid", action: .queue, player: player, toast: toast)

        #expect(toast.events.contains("success:Added to Queue"))
        #expect(player.queue.count == 1)
    }

    @Test func runHidesToastWhenStreamFails() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        defer { PipedAPI.session = .shared }

        let player = isolatedPlayer()
        let toast = SpyToast()
        await Playback.run(videoId: "vid", action: .play, player: player, toast: toast)

        #expect(toast.events.contains("loading:Loading..."))
        #expect(toast.events.contains("hide"))
        #expect(player.queue.isEmpty)
    }

    // MARK: - Retry integration (mutates global session + sleep, hence serialized here)

    /// Fixture session + no-op sleep so retries don't actually wait.
    private func withFastRetry(_ body: () async throws -> Void) async rethrows {
        let prevSession = PipedAPI.session
        let prevSleep = PipedAPI.sleep
        PipedAPI.session = MockURLProtocol.makeSession()
        PipedAPI.sleep = { _ in }
        defer { PipedAPI.session = prevSession; PipedAPI.sleep = prevSleep }
        try await body()
    }

    @Test func retryRecoversAfterTransientFailures() async throws {
        try await withFastRetry {
            MockURLProtocol.failThenSucceed(times: 2, error: URLError(.networkConnectionLost), json: #"{"items":[]}"#)
            let items = try await PipedAPI.search("x")
            #expect(items.isEmpty)
            #expect(MockURLProtocol.requestCount == 3) // 2 failures + 1 success
        }
    }

    @Test func retryGivesUpAfterMaxAttempts() async {
        await withFastRetry {
            MockURLProtocol.failThenSucceed(times: 99, error: URLError(.timedOut), json: #"{"items":[]}"#)
            await #expect(throws: (any Error).self) {
                _ = try await PipedAPI.search("x")
            }
            #expect(MockURLProtocol.requestCount == RetryPolicy.maxAttempts)
        }
    }

    @Test func retryDoesNotRetryDecodingErrors() async {
        await withFastRetry {
            MockURLProtocol.failThenSucceed(times: 0, error: URLError(.timedOut), json: "not json")
            await #expect(throws: (any Error).self) {
                _ = try await PipedAPI.search("x")
            }
            #expect(MockURLProtocol.requestCount == 1) // no retry on decode failure
        }
    }

    @Test func streamsDecodesChapters() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"title":"T","description":null,"uploader":"U","uploaderUrl":null,"duration":300,"hls":null,"audioStreams":[],"videoStreams":[],"thumbnailUrl":"t","uploadDate":null,"chapters":[{"title":"Intro","start":0,"image":"img"},{"title":"Part 2","start":120,"image":null}]}"#)
        let s = try await PipedAPI.streams("v")
        #expect(s.chapters?.count == 2)
        #expect(s.chapters?[1].title == "Part 2")
        #expect(s.chapters?[1].start == 120)
    }

    @Test func channelNextPageDecodes() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"content":[{"url":"/watch?v=v9","title":"More","thumbnail":"t","duration":30,"uploaderName":"U","uploadedDate":null,"uploaded":1}],"nextpage":"tok2"}"#)
        let page = try await PipedAPI.channelNextPage(channelId: "UC1", nextpage: "tok1")
        #expect(page.content.first?.videoId == "v9")
        #expect(page.nextpage == "tok2")
    }

    @Test func trendingDecodes() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"[{"url":"/watch?v=t1","title":"Trend","thumbnail":"t","duration":60,"uploaderName":"U","uploadedDate":null,"uploaded":1}]"#)
        let videos = try await PipedAPI.trending(region: "US")
        #expect(videos.first?.videoId == "t1")
    }

    @Test func commentsDecode() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"comments":[{"commentId":"c1","author":"@me","commentText":"Nice","likeCount":5,"verified":true,"pinned":false}],"disabled":false}"#)
        let response = try await PipedAPI.comments("v")
        #expect(response.comments.first?.author == "@me")
        #expect(response.comments.first?.likeCount == 5)
        #expect(response.disabled == false)
    }

    @Test func streamsDecodeRelatedStreams() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"title":"T","description":null,"uploader":"U","uploaderUrl":null,"duration":10,"hls":null,"audioStreams":[],"videoStreams":[],"thumbnailUrl":"t","uploadDate":null,"chapters":null,"relatedStreams":[{"url":"/watch?v=r1","title":"Related","thumbnail":"t","duration":20,"uploaderName":"U","uploadedDate":null,"uploaded":1}]}"#)
        let s = try await PipedAPI.streams("v")
        #expect(s.relatedStreams?.first?.videoId == "r1")
    }

    // MARK: - Playlists

    @Test func playlistURLEncodesId() {
        let url = PipedAPI.playlistURL("PL abc")
        #expect(url.absoluteString.contains("/playlists/"))
        #expect(!url.absoluteString.contains("PL abc"))
    }

    @Test func playlistDecodesVideos() async throws {
        try await withStub(#"{"name":"Mix","thumbnailUrl":"t","uploader":"U","relatedStreams":[{"url":"/watch?v=p1","title":"One","thumbnail":"t","duration":30,"uploaderName":"U","uploadedDate":null,"uploaded":1}]}"#) {
            let pl = try await PipedAPI.playlist("PLx")
            #expect(pl.name == "Mix")
            #expect(pl.relatedStreams.first?.videoId == "p1")
        }
    }

    @Test func playlistTabDecodesPlaylistItems() async throws {
        try await withStub(#"{"content":[{"url":"/playlist?list=PLa","name":"Best","thumbnail":"t","uploaderName":"U","videos":3}]}"#) {
            let items = try await PipedAPI.playlistTab("tok")
            #expect(items.first?.playlistId == "PLa")
            #expect(items.first?.videoCountText == "3 videos")
        }
    }

    // MARK: - FeedLoader (mutates the shared session, hence here in the one
    // serialized session suite)

    @Test func feedLoaderSortsNewestFirst() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"id":"c","name":"C","avatarUrl":null,"description":null,"relatedStreams":[{"url":"/watch?v=old","title":"Old","thumbnail":"t","duration":1,"uploaderName":"U","uploadedDate":null,"uploaded":100},{"url":"/watch?v=new","title":"New","thumbnail":"t","duration":1,"uploaderName":"U","uploadedDate":null,"uploaded":900}],"tabs":null,"nextpage":null}"#)
        let result = await FeedLoader.fetch(channels: [FollowedChannel(id: "c", name: "C", thumbnail: "")])
        #expect(result?.first?.videoId == "new")
        #expect(result?.last?.videoId == "old")
    }

    @Test func feedLoaderNilWhenNetworkYieldsNothing() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        let result = await FeedLoader.fetch(channels: [FollowedChannel(id: "c", name: "C", thumbnail: "")])
        #expect(result == nil)
    }

    // MARK: - DownloadCoordinator (also mutates the shared session)

    private func makeCoordDownloads() -> DownloadStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("coord-\(UUID().uuidString)", isDirectory: true)
        return DownloadStore(defaults: UserDefaults(suiteName: "coord-\(UUID().uuidString)")!, directory: dir) { _, dest, _ in
            try Data("m".utf8).write(to: dest)
        }
    }

    @Test func coordinatorDownloadsThenRemoves() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let downloads = makeCoordDownloads()
        let toast = SpyToast()
        await DownloadCoordinator.toggle(videoId: "v", title: "Row", artist: "A", thumbnail: "t", duration: 10, downloads: downloads, toast: toast)
        #expect(downloads.isDownloaded("v"))
        await DownloadCoordinator.toggle(videoId: "v", title: "Row", artist: "A", thumbnail: "t", duration: 10, downloads: downloads, toast: toast)
        #expect(downloads.isDownloaded("v") == false)
        #expect(toast.events.contains("success:Removed Download"))
    }

    @Test func coordinatorHidesToastWhenStreamFails() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        defer { PipedAPI.session = .shared }
        let downloads = makeCoordDownloads()
        let toast = SpyToast()
        await DownloadCoordinator.toggle(videoId: "v", title: "", artist: "", thumbnail: "", duration: 0, downloads: downloads, toast: toast)
        #expect(downloads.isDownloaded("v") == false)
        #expect(toast.events.contains("hide"))
    }

    // MARK: - PlaylistCoordinator (mutates the shared session)

    private func relatedStream(_ id: String) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(id)", title: id, thumbnail: "t", duration: 10, uploaderName: "U", uploadedDate: nil, uploaded: nil)
    }

    @Test func playAllPlaysFirstAndQueuesRest() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        MockURLProtocol.stub(json: Self.streamJSON)
        defer { PipedAPI.session = .shared }
        let player = isolatedPlayer()
        await PlaylistCoordinator.playAll([relatedStream("a"), relatedStream("b"), relatedStream("c")], player: player, toast: SpyToast())
        #expect(player.currentVideoId == "a")
        #expect(player.queue.count == 2)
    }

    @Test func playAllWithNoVideosIsNoOp() async {
        let player = isolatedPlayer()
        await PlaylistCoordinator.playAll([], player: player, toast: SpyToast())
        #expect(player.currentVideoId == nil)
    }
}
