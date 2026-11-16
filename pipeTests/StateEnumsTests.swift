import Testing
import Foundation
@testable import pipe

/// The smaller explicit state machines: queue-item resolution, toast,
/// transcript summary, and downloads (see docs/state-machines.md).
struct StateEnumsTests {
    @Test func queueItemResolutionDerivesFromTimestampAndAttempt() {
        var item = QueueItem.pending(videoId: "v", title: "T", artist: "a", thumbnail: "", duration: 1, uploadedDate: nil)
        #expect(item.resolution == .pending)
        item.resolveAttempt = .inFlight
        #expect(item.resolution == .resolving && item.resolution.isBusy)
        item.resolveAttempt = .failed
        #expect(item.resolution == .failed && item.resolution.isBusy)
        let now = Date()
        item.resolveAttempt = .none
        item.resolvedAt = now
        #expect(item.resolution == .resolved(now) && !item.resolution.isBusy)
    }

    @Test func resolveAttemptIsNotPersisted() throws {
        var item = QueueItem.pending(videoId: "v", title: "T", artist: "a", thumbnail: "", duration: 1, uploadedDate: nil)
        item.resolveAttempt = .inFlight
        let decoded = try JSONDecoder().decode(QueueItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.resolveAttempt == .none)
        #expect(decoded.resolution == .pending)
    }

    @Test func toastStateCarriesItsMessage() {
        #expect(ToastState.hidden.message == nil)
        #expect(ToastState.loading("L").message == "L")
        #expect(ToastState.success("S").message == "S")
        #expect(ToastState.error("E").message == "E")
    }

    @Test func summaryStateText() {
        #expect(SummaryState.idle.text == "")
        #expect(SummaryState.summarizing(partial: "half").text == "half")
        #expect(SummaryState.done("all").text == "all")
        #expect(SummaryState.failed("nope").text == "nope")
    }

    @Test func downloadStateAccessors() {
        let item = DownloadedItem(videoId: "v", title: "T", artist: "a", thumbnail: "", duration: 1, fileName: "v.m4a")
        #expect(DownloadState.none.progress == nil && !DownloadState.none.isDownloading && !DownloadState.none.isDownloaded)
        #expect(DownloadState.downloading(0.4).progress == 0.4 && DownloadState.downloading(0.4).isDownloading)
        #expect(DownloadState.downloaded(item).isDownloaded && DownloadState.downloaded(item).progress == nil)
    }
}

@MainActor
struct DownloadStateStoreTests {
    @Test func storeReportsOneStatePerVideo() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dl-\(UUID().uuidString)", isDirectory: true)
        let suite = try #require(UserDefaults(suiteName: "dl-\(UUID().uuidString)"))
        let store = DownloadStore(defaults: suite, directory: dir, downloader: { _, dest, progress in
            progress(0.5)
            try Data("x".utf8).write(to: dest)
        })
        #expect(store.state(for: "v") == .none)
        await store.download(videoId: "v", title: "T", artist: "a", thumbnail: "", duration: 1, audioUrl: "https://x/a.m4a", videoUrl: "")
        #expect(store.state(for: "v").isDownloaded)
        store.remove(videoId: "v")
        #expect(store.state(for: "v") == .none)
    }
}
