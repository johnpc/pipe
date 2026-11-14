import Testing
import Foundation
import AVFoundation
@testable import pipe

/// The player's native-HLS path: video mode plays the master, audio mode the
/// chosen language's rendition playlist, direct URLs only when there is no hls.
/// Nested under `StreamCompositionTests` to share its serialization (see there).
extension StreamCompositionTests {
@MainActor
@Suite(.serialized)
struct PlayerHLSTests {
    /// A master + two rendition playlists as local files.
    static func fixtures() throws -> (master: URL, en: URL, es: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hls-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let en = dir.appendingPathComponent("en.m3u8"), es = dir.appendingPathComponent("es.m3u8")
        let media = "#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nseg.ts\n#EXT-X-ENDLIST\n"
        try media.write(to: en, atomically: true, encoding: .utf8)
        try media.write(to: es, atomically: true, encoding: .utf8)
        let master = dir.appendingPathComponent("master.m3u8")
        try """
        #EXTM3U
        #EXT-X-MEDIA:URI="en.m3u8",TYPE=AUDIO,GROUP-ID="a",LANGUAGE="en-US",NAME="English - original",DEFAULT=NO
        #EXT-X-MEDIA:URI="es.m3u8",TYPE=AUDIO,GROUP-ID="a",LANGUAGE="es-US",NAME="Spanish",DEFAULT=NO
        #EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO="a"
        v.m3u8
        """.write(to: master, atomically: true, encoding: .utf8)
        return (master, en, es)
    }

    private func player(hls: String, language: String? = nil) -> PlayerState {
        let p = isolatedPlayer()
        var item = QueueItem(videoId: "v", title: "T", artist: "a", thumbnail: "", url: "https://x/muxed.mp4", audioUrl: "https://x/a.m4a",
                             videoOnlyUrl: "https://x/v.mp4", hlsUrl: hls, duration: 10, uploadedDate: nil)
        item.audioLanguage = language
        _ = p.enqueue(item, playNext: false)  // empty queue: starts playing
        return p
    }

    private func assetURL(_ p: PlayerState) async -> URL? {
        let deadline = Date().addingTimeInterval(20)
        while p.player == nil, Date() < deadline { try? await Task.sleep(nanoseconds: 50_000_000) }
        return (p.player?.currentItem?.asset as? AVURLAsset)?.url
    }

    @Test func audioModePlaysThePreferredLanguageRendition() async throws {
        let f = try Self.fixtures()
        let p = player(hls: f.master.absoluteString, language: "es")
        #expect(p.player == nil && p.isBuffering && p.isPlaying)  // resolving the master
        #expect(await assetURL(p) == f.es)
    }

    @Test func audioModeDefaultsToEnglish() async throws {
        let f = try Self.fixtures()
        #expect(await assetURL(player(hls: f.master.absoluteString)) == f.en)
    }

    @Test func videoModePlaysTheMaster() async throws {
        let f = try Self.fixtures()
        let p = isolatedPlayer()
        p.toggleVideoMode()
        p.addToQueue(videoId: "v", url: "https://x/muxed.mp4", hlsUrl: f.master.absoluteString, title: "T", artist: "a", thumbnail: "", duration: 10)
        #expect(await assetURL(p) == f.master)
    }

    @Test func unreadableMasterFallsBackToPlayingTheMasterURL() async throws {
        let missing = URL(fileURLWithPath: "/nonexistent/master.m3u8")
        #expect(await assetURL(player(hls: missing.absoluteString)) == missing)
    }

    @Test func withoutHLSTheDirectURLPlays() async {
        #expect(await assetURL(player(hls: "")) == URL(string: "https://x/a.m4a"))
    }

    @Test func supersededLoadNeverInstallsItsPlayer() async throws {
        let f = try Self.fixtures()
        let p = player(hls: f.master.absoluteString)
        p.stop()  // user moved on before the master was read
        try? await Task.sleep(nanoseconds: 800_000_000)
        #expect(p.player == nil)
    }

    @Test func resolvedStreamsCarryTheMasterIntoTheQueue() {
        let response = StreamResponse(title: "T", description: nil, uploader: "U", uploaderUrl: nil, duration: 5, hls: "https://m/master.m3u8",
                                      audioStreams: [], videoStreams: [], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
        let resolved = Playback.resolve(response, videoId: "v")
        #expect(resolved.hls == "https://m/master.m3u8")
        let p = isolatedPlayer()
        p.addToQueue(videoId: "now", url: "https://x/now.mp4", title: "n", artist: "a", thumbnail: "", duration: 1)
        _ = p.enqueue(.pending(videoId: "v", title: "T", artist: "U", thumbnail: "", duration: 5, uploadedDate: nil), playNext: false)
        p.applyResolvedURLs(resolved)
        #expect(p.queue[1].hlsUrl == "https://m/master.m3u8")
    }
}
}
