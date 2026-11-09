import Testing
import Foundation
import AVFoundation
@testable import pipe

private final class FixtureToken {}

/// Builds the video + audio composition from two bundled fragmented MP4s (the
/// same container shape YouTube serves), and the player's use of it.
@MainActor
struct StreamCompositionTests {
    static func fixture(_ name: String) throws -> URL {
        try #require(Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "mp4"))
    }

    @Test func composesVideoAndAudioTracks() async throws {
        let item = try await StreamComposition.playerItem(video: Self.fixture("composition_video"), audio: Self.fixture("composition_audio"))
        let composition = try #require(item.asset as? AVComposition)
        let tracks = try await composition.load(.tracks)
        #expect(Set(tracks.map(\.mediaType)) == [.video, .audio])
        let duration = try await composition.load(.duration).seconds
        #expect(duration > 0.5 && duration <= 1.1)
    }

    @Test func failsWhenASourceLacksItsTrack() async throws {
        // Swapped: the "video" source is audio-only.
        await #expect(throws: StreamComposition.Failure.missingTrack) {
            _ = try await StreamComposition.playerItem(video: Self.fixture("composition_audio"), audio: Self.fixture("composition_video"))
        }
    }

    @Test func failsOnUnreadableSource() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await StreamComposition.playerItem(video: URL(fileURLWithPath: "/nonexistent/v.mp4"), audio: Self.fixture("composition_audio"))
        }
    }

    // MARK: - Player wiring

    private func videoModePlayer(videoOnly: String, audio: String) -> PlayerState {
        let player = isolatedPlayer()
        player.toggleVideoMode()
        player.addToQueue(videoId: "v", url: "https://x/muxed.mp4", audioUrl: audio, videoOnlyUrl: videoOnly,
                          title: "T", artist: "a", thumbnail: "", duration: 10)
        return player
    }

    private func waitForPlayer(_ player: PlayerState) async -> AVPlayer? {
        let deadline = Date().addingTimeInterval(8)
        while player.player == nil, Date() < deadline { try? await Task.sleep(nanoseconds: 50_000_000) }
        return player.player
    }

    @Test func videoModePlaysTheComposedPair() async throws {
        let player = try videoModePlayer(videoOnly: Self.fixture("composition_video").absoluteString,
                                         audio: Self.fixture("composition_audio").absoluteString)
        player.playIndex(0)
        #expect(player.player == nil)  // still composing
        #expect(player.isBuffering && player.isPlaying)
        let avPlayer = try #require(await waitForPlayer(player))
        #expect(avPlayer.currentItem?.asset is AVComposition)
    }

    @Test func fallsBackToMuxedStreamWhenComposingFails() async throws {
        let player = try videoModePlayer(videoOnly: "file:///nonexistent/v.mp4",
                                         audio: Self.fixture("composition_audio").absoluteString)
        player.playIndex(0)
        let avPlayer = try #require(await waitForPlayer(player))
        let asset = try #require(avPlayer.currentItem?.asset as? AVURLAsset)
        #expect(asset.url.absoluteString == "https://x/muxed.mp4")
    }

    @Test func supersededLoadNeverInstallsItsPlayer() async throws {
        let player = try videoModePlayer(videoOnly: Self.fixture("composition_video").absoluteString,
                                         audio: Self.fixture("composition_audio").absoluteString)
        player.playIndex(0)
        // Before the composition lands, the user switches back to audio mode:
        // a synchronous single-stream load that must win.
        player.toggleVideoMode()
        let avPlayer = try #require(player.player)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        #expect(player.player === avPlayer)
        #expect((player.player?.currentItem?.asset as? AVURLAsset)?.url.absoluteString == Self.fixture("composition_audio").absoluteString)
    }
}
