import Foundation

/// Download/remove operations for DownloadStore, split out to keep files small.
extension DownloadStore {

    /// Download a video's media to disk and record it. No-op if already saved or
    /// in progress, or if neither URL is usable.
    func download(videoId: String, title: String, artist: String, thumbnail: String,
                  duration: Int, audioUrl: String, videoUrl: String) async {
        guard !isDownloaded(videoId), !inProgress.contains(videoId),
              let source = DownloadLogic.downloadURL(audioUrl: audioUrl, videoUrl: videoUrl),
              let remote = URL(string: source) else { return }

        inProgress.insert(videoId)
        defer { inProgress.remove(videoId) }

        let fileName = DownloadLogic.fileName(for: videoId)
        let dest = directory.appendingPathComponent(fileName)
        do {
            try await downloader(remote, dest)
            let item = DownloadedItem(videoId: videoId, title: title, artist: artist,
                                      thumbnail: thumbnail, duration: duration, fileName: fileName)
            items.insert(item, at: 0)
            persist()
        } catch {
            // Leave nothing recorded on failure.
        }
    }

    func remove(videoId: String) {
        guard let item = items.first(where: { $0.videoId == videoId }) else { return }
        try? FileManager.default.removeItem(at: localURL(for: item))
        items.removeAll { $0.videoId == videoId }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where index < items.count {
            remove(videoId: items[index].videoId)
        }
    }
}
