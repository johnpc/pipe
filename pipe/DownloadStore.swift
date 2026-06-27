import Foundation
import Combine

/// Persisted set of offline downloads. Metadata lives in UserDefaults; the media
/// files live in a directory on disk. Both the directory and the actual download
/// operation are injectable so the store is fully testable without the network
/// or the real Documents directory.
@MainActor
class DownloadStore: ObservableObject {
    @Published private(set) var items: [DownloadedItem] = []
    /// Video ids currently downloading (for in-progress UI).
    @Published private(set) var inProgress: Set<String> = []

    private let key = "downloadedItems"
    private let defaults: UserDefaults
    private let directory: URL
    /// Downloads a remote URL to a destination file. Injected for tests.
    private let downloader: (URL, URL) async throws -> Void

    init(defaults: UserDefaults = .standard,
         directory: URL? = nil,
         downloader: ((URL, URL) async throws -> Void)? = nil) {
        self.defaults = defaults
        self.directory = directory ?? DownloadStore.defaultDirectory()
        self.downloader = downloader ?? DownloadStore.urlSessionDownloader
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    nonisolated deinit {}

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Downloads", isDirectory: true)
    }

    private static func urlSessionDownloader(_ remote: URL, _ dest: URL) async throws {
        let (tmp, _) = try await URLSession.shared.download(from: remote)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
    }

    private func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([DownloadedItem].self, from: data) {
            // Keep only entries whose file is still present.
            items = decoded.filter { FileManager.default.fileExists(atPath: localURL(for: $0).path) }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    func isDownloaded(_ videoId: String) -> Bool {
        items.contains { $0.videoId == videoId }
    }

    /// Local file URL for a downloaded item's media.
    func localURL(for item: DownloadedItem) -> URL {
        directory.appendingPathComponent(item.fileName)
    }

    /// Local media URL string for a video id, if it's downloaded; else nil.
    func localURLString(for videoId: String) -> String? {
        guard let item = items.first(where: { $0.videoId == videoId }) else { return nil }
        let url = localURL(for: item)
        return FileManager.default.fileExists(atPath: url.path) ? url.absoluteString : nil
    }

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
