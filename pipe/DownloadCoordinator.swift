import Foundation

/// Orchestrates a row-level download toggle: if already downloaded, remove it;
/// otherwise fetch the stream, resolve URLs, and download — with toasts. Kept
/// out of the views so the flow is reusable and the views stay declarative.
enum DownloadCoordinator {
    /// Toggle download state for a video. `title`/`artist`/`thumbnail`/`duration`
    /// are the row's known metadata (used so the Downloads list shows something
    /// even before the stream resolves).
    @MainActor
    static func toggle(videoId: String, title: String, artist: String, thumbnail: String,
                       duration: Int, downloads: DownloadStore, toast: ToastManaging? = nil) async {
        let toast = toast ?? ToastManager.shared
        if downloads.isDownloaded(videoId) {
            downloads.remove(videoId: videoId)
            toast.showSuccess("Removed Download")
            return
        }
        toast.showLoading("Downloading…")
        guard let stream = try? await PipedAPI.streams(videoId) else {
            toast.hide()
            return
        }
        let r = Playback.resolve(stream, videoId: videoId)
        await downloads.download(videoId: videoId, title: title.isEmpty ? r.title : title,
                                 artist: artist.isEmpty ? r.artist : artist,
                                 thumbnail: thumbnail.isEmpty ? r.thumbnail : thumbnail,
                                 duration: duration > 0 ? duration : r.duration,
                                 audioUrl: r.audioUrl, videoUrl: r.url)
        toast.showSuccess(downloads.isDownloaded(videoId) ? "Downloaded" : "Download Failed")
    }
}
