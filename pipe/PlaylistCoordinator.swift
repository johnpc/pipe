import Foundation

/// Orchestrates "Play All" for a playlist: play the first video immediately,
/// then resolve and append the rest to the queue in order. Kept out of the view
/// so the flow is reusable and testable. Streams are resolved one by one because
/// playlist rows carry no stream URLs.
enum PlaylistCoordinator {
    /// Play the playlist top-to-bottom. The first track plays right away; the
    /// remaining tracks are appended to the queue as their streams resolve.
    @MainActor
    static func playAll(_ videos: [RelatedStream], player: PlayerState, toast: ToastManaging? = nil) async {
        let toast = toast ?? ToastManager.shared
        guard let first = videos.first else { return }
        await Playback.run(videoId: first.videoId, action: .play, player: player, toast: toast)
        for video in videos.dropFirst() {
            await Playback.run(videoId: video.videoId, action: .queue, player: player, toast: SilentToast())
        }
    }
}

/// A no-op toast sink so queueing the tail of a playlist doesn't spam the user
/// with one toast per track (only the initial "Now Playing" should show).
private struct SilentToast: ToastManaging {
    func showLoading(_ message: String) {}
    func showSuccess(_ message: String) {}
    func showError(_ message: String) {}
    func hide() {}
}
