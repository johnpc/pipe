import Foundation

/// Shared playback orchestration extracted out of the view layer.
///
/// All list views (Feed, Search, Channel, Recents) need the identical
/// "fetch stream → resolve URL → play or enqueue → show toast" flow.
/// Keeping it here means the views only render and this logic is unit-testable.
enum Playback {
    /// What to do with a resolved stream.
    enum Action { case play, queue, playNext }

    /// Build the metadata a player call needs from a decoded stream, resolving
    /// both the video and audio-only URLs. Pure and synchronous so it can be
    /// exercised directly in tests.
    static func resolve(_ stream: StreamResponse, videoId: String) -> ResolvedStream {
        ResolvedStream(
            videoId: videoId,
            url: getStreamUrl(stream),
            audioUrl: getAudioStreamUrl(stream),
            title: stream.title,
            artist: stream.uploader,
            thumbnail: stream.thumbnailUrl,
            duration: stream.duration,
            uploadedDate: stream.uploadDate,
            chapters: stream.chapters ?? []
        )
    }

    /// Apply a resolved stream to the player for the given action.
    @MainActor
    static func apply(_ resolved: ResolvedStream, action: Action, to player: PlayerState) {
        // Make the stream's chapters available for the now-playing label.
        player.registerChapters(resolved.chapters, for: resolved.videoId)
        switch action {
        case .play:
            player.play(videoId: resolved.videoId, urlString: resolved.url, audioUrl: resolved.audioUrl, title: resolved.title, artist: resolved.artist, thumbnail: resolved.thumbnail, duration: resolved.duration, uploadedDate: resolved.uploadedDate)
        case .queue:
            player.addToQueue(videoId: resolved.videoId, url: resolved.url, audioUrl: resolved.audioUrl, title: resolved.title, artist: resolved.artist, thumbnail: resolved.thumbnail, duration: resolved.duration, uploadedDate: resolved.uploadedDate)
        case .playNext:
            player.playNextInQueue(videoId: resolved.videoId, url: resolved.url, audioUrl: resolved.audioUrl, title: resolved.title, artist: resolved.artist, thumbnail: resolved.thumbnail, duration: resolved.duration, uploadedDate: resolved.uploadedDate)
        }
    }

    /// Toast copy for each phase of an action. Pure so tests can assert it.
    static func loadingMessage(for action: Action) -> String {
        action == .play ? "Loading..." : "Adding..."
    }

    static func successMessage(for action: Action) -> String {
        switch action {
        case .play: return "Now Playing"
        case .queue: return "Added to Queue"
        case .playNext: return "Playing Next"
        }
    }

    /// Full async flow used by the views: fetch, resolve, apply, toast.
    /// `toast` defaults to the shared manager; tests pass a spy. On failure it
    /// logs a structured event (so the failure is diagnosable from the exported/
    /// uploaded log) and shows a toast naming *why* it failed.
    @MainActor
    static func run(videoId: String, action: Action, player: PlayerState, toast: ToastManaging? = nil) async {
        let toast = toast ?? ToastManager.shared
        toast.showLoading(loadingMessage(for: action))
        do {
            let stream = try await PipedAPI.streams(videoId)
            apply(resolve(stream, videoId: videoId), action: action, to: player)
            toast.showSuccess(successMessage(for: action))
        } catch {
            player.log.event("playbackError", errorEventName(for: action),
                             fields: ["videoId": videoId, "reason": errorReason(error),
                                      "error": error.localizedDescription])
            toast.showError(errorMessage(for: action, error: error))
        }
    }
}

/// Value type carrying everything the player needs to start an item.
struct ResolvedStream: Equatable {
    let videoId: String
    let url: String
    let audioUrl: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
    let uploadedDate: String?
    var chapters: [Chapter] = []
}

/// Protocol over ToastManager so playback logic can be tested without the singleton.
@MainActor
protocol ToastManaging {
    func showLoading(_ msg: String)
    func showSuccess(_ msg: String)
    func showError(_ msg: String)
    func hide()
}

extension ToastManager: ToastManaging {}
