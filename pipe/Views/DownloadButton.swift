import SwiftUI

/// Toolbar download toggle for a video: downloads the audio for offline play, or
/// removes an existing download. Shows progress while downloading.
struct DownloadButton: View {
    let videoId: String
    let stream: StreamResponse
    @ObservedObject var downloads: DownloadStore

    var body: some View {
        let state = downloads.state(for: videoId)
        Button { toggle(isDownloaded: state.isDownloaded) } label: {
            if let progress = state.progress {
                // Determinate ring showing real download progress.
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: state.isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
            }
        }
        .accessibilityIdentifier("downloadButton")
        .disabled(state.isDownloading)
    }

    private func toggle(isDownloaded: Bool) {
        if isDownloaded {
            downloads.remove(videoId: videoId)
            ToastManager.shared.showSuccess("Removed Download")
            return
        }
        let r = Playback.resolve(stream, videoId: videoId)
        ToastManager.shared.showLoading("Downloading…")
        Task {
            await downloads.download(videoId: videoId, title: r.title, artist: r.artist, thumbnail: r.thumbnail, duration: r.duration, audioUrl: r.audioUrl, videoUrl: r.url)
            ToastManager.shared.showSuccess(downloads.isDownloaded(videoId) ? "Downloaded" : "Download Failed")
        }
    }
}
