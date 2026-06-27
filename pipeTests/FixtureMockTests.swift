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
        #expect(FixtureRouter.fixtureName(for: URL(string: "https://x/comments/abc")!) == nil)
    }

    // MARK: - MockMode

    @Test func isEnabledDetectsLaunchArgument() {
        #expect(MockMode.isEnabled([MockMode.launchArgument]) == true)
        #expect(MockMode.isEnabled(["other"]) == false)
        #expect(MockMode.isEnabled([]) == false)
    }

    // MARK: - FixtureURLProtocol serving

    @Test func protocolCanInitForKnownPathsOnly() {
        let known = URLRequest(url: URL(string: "https://x/search?q=a")!)
        let unknown = URLRequest(url: URL(string: "https://x/unknown")!)
        #expect(FixtureURLProtocol.canInit(with: known) == true)
        #expect(FixtureURLProtocol.canInit(with: unknown) == false)
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
