import Testing
import Foundation
@testable import pipe

@MainActor
struct PlaybackTests {

    // MARK: - Pure helpers

    @Test func loadingAndSuccessMessages() {
        #expect(Playback.loadingMessage(for: .play) == "Loading...")
        #expect(Playback.loadingMessage(for: .queue) == "Adding...")
        #expect(Playback.loadingMessage(for: .playNext) == "Adding...")
        #expect(Playback.successMessage(for: .play) == "Now Playing")
        #expect(Playback.successMessage(for: .queue) == "Added to Queue")
        #expect(Playback.successMessage(for: .playNext) == "Playing Next")
        #expect(Playback.errorMessage(for: .play) == "Couldn't play — try again")
        #expect(Playback.errorMessage(for: .queue) == "Couldn't add — try again")
        #expect(Playback.errorMessage(for: .playNext) == "Couldn't add — try again")
    }

    @Test func resolveMapsStreamFields() {
        let stream = StreamResponse(title: "T", description: "d", uploader: "U", uploaderUrl: nil, duration: 42, hls: nil, audioStreams: [AudioStream(url: "https://x/audio.m4a", bitrate: 128000, mimeType: "audio/mp4")], videoStreams: [VideoStream(url: "https://x/a.mp4", quality: "360p", mimeType: "video/mp4", videoOnly: false)], thumbnailUrl: "thumb", uploadDate: "2026-01-01", chapters: nil, relatedStreams: nil)
        let resolved = Playback.resolve(stream, videoId: "vid1")
        #expect(resolved.videoId == "vid1")
        #expect(resolved.url == "https://x/a.mp4")
        #expect(resolved.audioUrl == "https://x/audio.m4a")
        #expect(resolved.title == "T")
        #expect(resolved.artist == "U")
        #expect(resolved.thumbnail == "thumb")
        #expect(resolved.duration == 42)
        #expect(resolved.uploadedDate == "2026-01-01")
    }

    // MARK: - apply()

    @Test func applyPlayInsertsAndStartsQueue() {
        let player = isolatedPlayer()
        let resolved = ResolvedStream(videoId: "v", url: "bad://url", audioUrl: "", title: "t", artist: "a", thumbnail: "th", duration: 10, uploadedDate: nil)
        Playback.apply(resolved, action: .play, to: player)
        #expect(player.queue.count == 1)
        #expect(player.currentIndex == 0)
        #expect(player.currentTitle == "t")
    }

    @Test func applyQueueAppends() {
        let player = isolatedPlayer()
        let a = ResolvedStream(videoId: "v1", url: "u1", audioUrl: "", title: "t1", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        let b = ResolvedStream(videoId: "v2", url: "u2", audioUrl: "", title: "t2", artist: "a", thumbnail: "", duration: 0, uploadedDate: nil)
        Playback.apply(a, action: .queue, to: player)
        Playback.apply(b, action: .queue, to: player)
        #expect(player.queue.count == 2)
        #expect(player.queue[1].videoId == "v2")
    }

    // NOTE: The full async `Playback.run` flow (which stubs the network via the
    // shared `PipedAPI.session`) is tested in `PipedAPITests`, which is
    // `.serialized` so the global session mutation cannot race other tests.
}

/// Records toast calls so playback flow can be asserted without UI.
@MainActor
final class SpyToast: ToastManaging {
    var events: [String] = []
    func showLoading(_ msg: String) { events.append("loading:\(msg)") }
    func showSuccess(_ msg: String) { events.append("success:\(msg)") }
    func showError(_ msg: String) { events.append("error:\(msg)") }
    func hide() { events.append("hide") }
}
