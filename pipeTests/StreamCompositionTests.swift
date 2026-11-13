import Testing
import Foundation
import AVFoundation
@testable import pipe

private final class FixtureToken {}

/// Builds the HLS presentation of a video-only + audio pair from two bundled
/// fragmented MP4s (the same container shape YouTube serves), and the player's
/// use of it.
@MainActor
struct StreamCompositionTests {
    static func fixture(_ name: String) throws -> URL {
        try #require(Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "mp4"))
    }

    @Test func describesBothStreamsAsPlaylists() async throws {
        let video = try Self.fixture("composition_video"), audio = try Self.fixture("composition_audio")
        let stream = try await StreamComposition.build(video: video, audio: audio)
        let asset = try #require(stream.item.asset as? AVURLAsset)
        #expect(asset.url == HLSPlaylist.url(HLSPlaylist.master))
        let videoList = try #require(stream.loader.playlist(for: HLSPlaylist.url(HLSPlaylist.video)))
        #expect(String(decoding: videoList, as: UTF8.self).contains("BYTERANGE=\"778@0\""))
        #expect(String(decoding: videoList, as: UTF8.self).contains("#EXT-X-BYTERANGE:3910@830\n\(video.absoluteString)"))
        let audioList = try #require(stream.loader.playlist(for: HLSPlaylist.url(HLSPlaylist.audio)))
        #expect(String(decoding: audioList, as: UTF8.self).contains(audio.absoluteString))
        #expect(stream.loader.playlist(for: asset.url) != nil)
    }

    @Test func avFoundationReadsThePlaylistsThroughTheLoader() async throws {
        let stream = try await StreamComposition.build(video: Self.fixture("composition_video"), audio: Self.fixture("composition_audio"))
        // Loading the duration makes AVFoundation fetch master + media playlists
        // via the resource loader; the fixtures are one ~1s fragment each.
        let duration = try await stream.item.asset.load(.duration).seconds
        #expect(duration > 0.5 && duration <= 1.1)
    }

    @Test func failsOnUnreadableSource() async throws {
        await #expect(throws: (any Error).self) {
            _ = try await StreamComposition.build(video: URL(fileURLWithPath: "/nonexistent/v.mp4"), audio: Self.fixture("composition_audio"))
        }
    }

    @Test func failsOnAnUnindexedSource() async throws {
        let plain = FileManager.default.temporaryDirectory.appendingPathComponent("plain-\(UUID().uuidString).mp4")
        try Data(count: 4096).write(to: plain)
        defer { try? FileManager.default.removeItem(at: plain) }
        await #expect(throws: MP4SegmentIndex.Failure.noIndex) {
            _ = try await StreamComposition.build(video: plain, audio: Self.fixture("composition_audio"))
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
        let deadline = Date().addingTimeInterval(20)  // generous: the full suite runs in parallel
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
        #expect((avPlayer.currentItem?.asset as? AVURLAsset)?.url.scheme == HLSPlaylist.scheme)
        #expect(player.composedLoader != nil)  // kept alive for the item's lifetime
    }

    @Test func fallsBackToMuxedStreamWhenComposingFails() async throws {
        let buffer = RingBufferSink()
        let player = try videoModePlayer(videoOnly: "file:///nonexistent/v.mp4",
                                         audio: Self.fixture("composition_audio").absoluteString)
        player.log = PlaybackLog(buffer: buffer)
        player.playIndex(0)
        let avPlayer = try #require(await waitForPlayer(player))
        let asset = try #require(avPlayer.currentItem?.asset as? AVURLAsset)
        #expect(asset.url.absoluteString == "https://x/muxed.mp4")
        // The failure is logged with its domain and code, not just a message.
        let entry = buffer.snapshot().first { $0.message == "compose failed, using muxed" }
        #expect(entry?.fields["error"]?.contains("NSURLErrorDomain") == true)
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
        let audioOnly = try Self.fixture("composition_audio").absoluteString
        #expect(player.player === avPlayer)
        #expect((player.player?.currentItem?.asset as? AVURLAsset)?.url.absoluteString == audioOnly)
    }
}
