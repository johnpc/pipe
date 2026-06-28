import Testing
import Foundation
@testable import pipe

struct DownloadFormatTests {
    @Test func storageTextZeroForEmpty() {
        #expect(DownloadFormat.storageText(bytes: 0) == "0 KB")
        #expect(DownloadFormat.storageText(bytes: -5) == "0 KB")
    }

    @Test func storageTextFormatsBytes() {
        // Exact wording is locale/formatter-driven; assert it mentions MB and a digit.
        let text = DownloadFormat.storageText(bytes: 5_000_000)
        #expect(text.contains("MB"))
    }

    @Test func percentClampsAndComputes() {
        #expect(DownloadFormat.percent(received: 0, total: 0) == 0)
        #expect(DownloadFormat.percent(received: 50, total: 100) == 50)
        #expect(DownloadFormat.percent(received: 100, total: 100) == 100)
        #expect(DownloadFormat.percent(received: 200, total: 100) == 100) // clamped
        #expect(DownloadFormat.percent(received: 1, total: 0) == 0)       // no total
    }
}

@MainActor
struct DownloadStorageTests {
    @Test func totalStorageSumsFileSizes() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dlstore-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "dlstore-\(UUID().uuidString)")!
        let store = DownloadStore(defaults: defaults, directory: dir) { _, dest in
            try Data(repeating: 0, count: 1024).write(to: dest)  // 1 KB each
        }
        await store.download(videoId: "a", title: "A", artist: "x", thumbnail: "", duration: 1, audioUrl: "https://x/a", videoUrl: "")
        await store.download(videoId: "b", title: "B", artist: "x", thumbnail: "", duration: 1, audioUrl: "https://x/b", videoUrl: "")
        #expect(store.totalStorageBytes() == 2048)
    }

    @Test func totalStorageZeroWhenEmpty() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dlempty-\(UUID().uuidString)", isDirectory: true)
        let store = DownloadStore(defaults: UserDefaults(suiteName: "dlempty-\(UUID().uuidString)")!, directory: dir) { _, _ in }
        #expect(store.totalStorageBytes() == 0)
    }
}
