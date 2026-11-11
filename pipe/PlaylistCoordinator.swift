import Foundation

/// Orchestrates "Play All" for a playlist: play the first video immediately,
/// then resolve and append the rest to the queue in order. Kept out of the view
/// so the flow is reusable and testable.
enum PlaylistCoordinator {
    /// Play the playlist top-to-bottom. The first track plays right away and the
    /// rest land in the queue at once (as pending items); their stream URLs then
    /// resolve one at a time in play order, so a long playlist doesn't fire
    /// dozens of requests at the instance simultaneously.
    @MainActor
    static func playAll(_ videos: [RelatedStream], player: PlayerState, toast: ToastManaging? = nil) async {
        let toast = toast ?? ToastManager.shared
        guard let first = videos.first else { return }
        await Playback.run(videoId: first.videoId, action: .play, player: player, toast: toast)
        let silent = SilentToast()
        let pending = videos.dropFirst().filter {
            Playback.enqueueNow(QueueItem(pending: $0), action: .queue, player: player, toast: silent)
        }
        for video in pending {
            await Playback.resolvePending(video.videoId, player: player, toast: silent)
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
