import Testing
import Foundation
@testable import pipe

@MainActor
struct DownloadStoreTests {

    /// A store backed by a temp directory and a stub downloader that writes a
    /// placeholder file — no network, no real Documents dir.
    private func makeStore(failing: Bool = false) -> (DownloadStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dltest-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "dl-\(UUID().uuidString)")!
        let store = DownloadStore(defaults: defaults, directory: dir) { _, dest, _ in
            if failing { throw URLError(.notConnectedToInternet) }
            try "media".data(using: .utf8)!.write(to: dest)
        }
        return (store, dir)
    }

    @Test func downloadRecordsItemAndWritesFile() async {
        let (store, _) = makeStore()
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "th", duration: 10, audioUrl: "https://x/a.m4a", videoUrl: "")
        #expect(store.isDownloaded("v"))
        #expect(store.items.first?.videoId == "v")
        #expect(store.localURLString(for: "v") != nil)
    }

    @Test func downloadReportsProgressThenClearsIt() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dlprog-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "dlprog-\(UUID().uuidString)")!
        // Stub downloader emits a few progress fractions before finishing.
        let store = DownloadStore(defaults: defaults, directory: dir) { _, dest, onProgress in
            onProgress(0.25); onProgress(0.5); onProgress(1.0)
            try "media".data(using: .utf8)!.write(to: dest)
        }
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 1, audioUrl: "https://x/a", videoUrl: "")
        // Recorded as downloaded, and progress is cleared once finished.
        #expect(store.isDownloaded("v"))
        #expect(store.progress["v"] == nil)
    }

    @Test func downloadIsIdempotent() async {
        let (store, _) = makeStore()
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 10, audioUrl: "https://x/a", videoUrl: "")
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 10, audioUrl: "https://x/a", videoUrl: "")
        #expect(store.items.count == 1)
    }

    @Test func downloadNoOpWithoutUsableURL() async {
        let (store, _) = makeStore()
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 10, audioUrl: "", videoUrl: "")
        #expect(store.isDownloaded("v") == false)
    }

    @Test func failedDownloadRecordsNothing() async {
        let (store, _) = makeStore(failing: true)
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 10, audioUrl: "https://x/a", videoUrl: "")
        #expect(store.isDownloaded("v") == false)
        #expect(store.localURLString(for: "v") == nil)
    }

    @Test func removeDeletesEntryAndFile() async {
        let (store, _) = makeStore()
        await store.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 10, audioUrl: "https://x/a", videoUrl: "")
        let url = store.localURLString(for: "v")!
        store.remove(videoId: "v")
        #expect(store.isDownloaded("v") == false)
        #expect(FileManager.default.fileExists(atPath: URL(string: url)!.path) == false)
    }

    @Test func removeAtOffsets() async {
        let (store, _) = makeStore()
        await store.download(videoId: "a", title: "A", artist: "x", thumbnail: "", duration: 1, audioUrl: "https://x/a", videoUrl: "")
        await store.download(videoId: "b", title: "B", artist: "x", thumbnail: "", duration: 1, audioUrl: "https://x/b", videoUrl: "")
        // items are [b, a]; remove index 0 (b)
        store.remove(at: IndexSet(integer: 0))
        #expect(store.items.map(\.videoId) == ["a"])
    }

    @Test func metadataPersistsAcrossInstancesWhenFilePresent() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dlp-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "dlp-\(UUID().uuidString)")!
        let writer: DownloadOperation = { _, dest, _ in try "m".data(using: .utf8)!.write(to: dest) }
        let s1 = DownloadStore(defaults: defaults, directory: dir, downloader: writer)
        await s1.download(videoId: "v", title: "T", artist: "A", thumbnail: "", duration: 1, audioUrl: "https://x/a", videoUrl: "")
        let s2 = DownloadStore(defaults: defaults, directory: dir, downloader: writer)
        #expect(s2.isDownloaded("v"))
    }

    @Test func localURLStringNilForUnknown() {
        let (store, _) = makeStore()
        #expect(store.localURLString(for: "nope") == nil)
    }
}
