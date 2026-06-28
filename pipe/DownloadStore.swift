import Foundation
import Combine

/// Persisted set of offline downloads. Metadata lives in UserDefaults; the media
/// files live in a directory on disk. Both the directory and the actual download
/// operation are injectable so the store is fully testable without the network
/// or the real Documents directory.
@MainActor
class DownloadStore: ObservableObject {
    // Mutated only within DownloadStore and its extensions (same module).
    @Published var items: [DownloadedItem] = []
    /// Video ids currently downloading (for in-progress UI).
    @Published var inProgress: Set<String> = []
    /// Live download progress (0...1) keyed by video id, while in progress.
    @Published var progress: [String: Double] = [:]

    private let key = "downloadedItems"
    private let defaults: UserDefaults
    let directory: URL
    /// Downloads a remote URL to a destination file, reporting progress.
    /// Injected for tests.
    let downloader: DownloadOperation

    init(defaults: UserDefaults = .standard,
         directory: URL? = nil,
         downloader: DownloadOperation? = nil) {
        self.defaults = defaults
        self.directory = directory ?? DownloadStore.defaultDirectory()
        self.downloader = downloader ?? ProgressDownloader.operation
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    nonisolated deinit {}

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Downloads", isDirectory: true)
    }

    private func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([DownloadedItem].self, from: data) {
            // Keep only entries whose file is still present.
            items = decoded.filter { FileManager.default.fileExists(atPath: localURL(for: $0).path) }
        }
    }

    func persist() {
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
}
