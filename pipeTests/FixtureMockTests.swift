import Testing
import Foundation
@testable import pipe

struct FixtureMockTests {

    // MARK: - FixtureRouter

    @Test func routesSearch() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/search?q=cats")!) == "search")
    }

    @Test func routesChannelTabsBeforeChannel() {
        // /channels/tabs must not be mistaken for /channel/.
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/channels/tabs?data=z")!) == "channelTab")
    }

    @Test func routesChannel() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/channel/UC123")!) == "channel")
    }

    @Test func routesStreams() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/streams/abc")!) == "streams")
    }

    @Test func unknownPathReturnsNil() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/subscriptions/abc")!) == nil)
    }

    @Test func routesTrendingAndComments() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/trending?region=US")!) == "trending")
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/comments/abc")!) == "comments")
    }

    @Test func routesPlaylistDetail() {
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/playlists/PLabc")!) == "playlist")
    }

    @Test func routesPlaylistTabByDataToken() {
        // A channels/tabs request whose data token mentions "playlist" serves the
        // playlist-tab fixture; any other tab serves the video tab fixture.
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/channels/tabs?data=%7B%22contentFilters%22:%5B%22playlists%22%5D%7D")!) == "channelPlaylistTab")
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/channels/tabs?data=shorts")!) == "channelTab")
    }

    // MARK: - MockMode

    @Test func fallbackOverrideReadsItsValue() {
        let args = ["--uitest-instance", "http://127.0.0.1:1", "--uitest-fallback-instance", "http://127.0.0.1:8765"]
        #expect(MockMode.fallbackOverride(args) == "http://127.0.0.1:8765")
        #expect(MockMode.fallbackOverride(["--uitest-fallback-instance"]) == nil)
        #expect(MockMode.fallbackOverride(["--uitest-mock"]) == nil)
    }

    @Test func pointInstancesWritesBothInstancesOnlyForARealBackend() throws {
        let suite = try #require(UserDefaults(suiteName: "mock-fallback-\(UUID().uuidString)"))
        #expect(!MockMode.pointInstances(from: ["--uitest-mock"], defaults: suite))
        #expect(suite.string(forKey: AppSettings.instanceKey) == nil)
        #expect(MockMode.pointInstances(from: ["--uitest-instance", "http://127.0.0.1:8765"], defaults: suite))
        #expect(suite.string(forKey: AppSettings.instanceKey) == "http://127.0.0.1:8765")
        #expect(suite.string(forKey: AppSettings.fallbackKey) == nil)
        let both = ["--uitest-instance", "http://127.0.0.1:1", "--uitest-fallback-instance", "http://127.0.0.1:8765"]
        #expect(MockMode.pointInstances(from: both, defaults: suite))
        #expect(suite.string(forKey: AppSettings.instanceKey) == "http://127.0.0.1:1")
        #expect(suite.string(forKey: AppSettings.fallbackKey) == "http://127.0.0.1:8765")
    }

    @Test func instanceOverrideEnablesHermeticModeWithoutFixtures() throws {
        #expect(MockMode.instanceOverride(["--uitest-instance", "http://127.0.0.1:8765"]) == "http://127.0.0.1:8765")
        #expect(MockMode.instanceOverride(["--uitest-instance"]) == nil)  // no value
        #expect(MockMode.instanceOverride(["--uitest-mock"]) == nil)
        #expect(MockMode.isEnabled(["--uitest-instance", "http://127.0.0.1:8765"]))
        let suite = try #require(UserDefaults(suiteName: "mock-instance-\(UUID().uuidString)"))
        MockMode.pointInstance(at: "http://127.0.0.1:8765", defaults: suite)
        #expect(AppSettings(defaults: suite).instanceURL == "http://127.0.0.1:8765")
    }

    @Test func mockModeConfiguresAnInstanceUnlessAskedNotTo() throws {
        // Fixtures answer by path, so the host is arbitrary — but without one the
        // app would sit on the setup screen in every scenario.
        let suite = try #require(UserDefaults(suiteName: "mock-inst-\(UUID().uuidString)"))
        MockMode.pointInstance(at: "https://fixtures.uitest", defaults: suite)
        #expect(AppSettings(defaults: suite).isConfigured)
        #expect(MockMode.noInstanceArgument == "--uitest-no-instance")
        pipedBase = AppSettings.legacyInstance
    }

    @Test func isEnabledDetectsLaunchArgument() {
        #expect(MockMode.isEnabled([MockMode.launchArgument]) == true)
        #expect(MockMode.isEnabled(["other"]) == false)
        #expect(MockMode.isEnabled([]) == false)
    }

    @Test func resetClearsDefaultsDomainAndDownloads() throws {
        let suiteName = "reset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("v1", forKey: "downloadedItems")
        #expect(defaults.string(forKey: "downloadedItems") == "v1")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("reset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("m".utf8).write(to: dir.appendingPathComponent("a.m4a"))

        MockMode.reset(defaults: defaults, domain: suiteName, downloads: dir)

        #expect(defaults.string(forKey: "downloadedItems") == nil)
        #expect(FileManager.default.fileExists(atPath: dir.path) == false)
    }

    @Test func resetWithNilDomainStillRemovesDownloads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("reset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        MockMode.reset(defaults: .standard, domain: nil, downloads: dir)
        #expect(FileManager.default.fileExists(atPath: dir.path) == false)
    }

    // MARK: - FixtureURLProtocol serving

    @Test func protocolCanInitForKnownPathsOnly() {
        let known = URLRequest(url: URL(string: "https://x/search?q=a")!)
        let unknown = URLRequest(url: URL(string: "https://x/unknown")!)
        #expect(FixtureURLProtocol.canInit(with: known) == true)
        #expect(FixtureURLProtocol.canInit(with: unknown) == false)
    }

    @Test func protocolAnswers502WhenInstanceIsDown() async throws {
        // `--uitest-down-instance` must look exactly like a dead instance behind
        // nginx: a 502 with an HTML body, only for /streams/.
        FixtureURLProtocol.streamMode = .instanceDown
        defer { FixtureURLProtocol.streamMode = .normal }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(from: URL(string: "https://x/streams/abc")!)
        #expect((response as? HTTPURLResponse)?.statusCode == 502)
        #expect(data == FixtureURLProtocol.downBody)
    }

    @Test func streamModeIsOneValueFromTheLaunchFlags() {
        #expect(FixtureURLProtocol.StreamMode.from(arguments: ["--uitest-mock"]) == .normal)
        #expect(FixtureURLProtocol.StreamMode.from(arguments: ["--uitest-mock", "--uitest-fail-streams"]) == .networkFailure)
        #expect(FixtureURLProtocol.StreamMode.from(arguments: ["--uitest-mock", "--uitest-error-streams"]) == .pipedError)
        #expect(FixtureURLProtocol.StreamMode.from(arguments: ["--uitest-mock", "--uitest-down-instance"]) == .instanceDown)
    }

    @Test func downArgumentIsDistinctFromOtherFlags() {
        #expect(MockMode.downArgument == "--uitest-down-instance")
        #expect(Set([MockMode.failArgument, MockMode.errorArgument, MockMode.downArgument]).count == 3)
    }

    @Test func protocolServesInjectedFixtureData() async throws {
        // Override the loader so the test doesn't depend on the app bundle.
        let previous = FixtureURLProtocol.loader
        defer { FixtureURLProtocol.loader = previous }
        FixtureURLProtocol.loader = { name in
            name == "search" ? Data(#"{"items":[]}"#.utf8) : nil
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(from: URL(string: "https://x/search?q=a")!)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == #"{"items":[]}"#)
    }
}
