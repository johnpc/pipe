import Testing
import Foundation
@testable import pipe

struct DownloadLogicTests {
    @Test func fileNameIsSafeAndDeterministic() {
        #expect(DownloadLogic.fileName(for: "abc123") == "dl_abc123.mp4")
        // Same input → same name.
        #expect(DownloadLogic.fileName(for: "abc123") == DownloadLogic.fileName(for: "abc123"))
    }

    @Test func fileNameSanitizesUnsafeCharacters() {
        let name = DownloadLogic.fileName(for: "a/b?c=d")
        #expect(!name.contains("/"))
        #expect(!name.contains("?"))
        #expect(!name.contains("="))
        #expect(name.hasPrefix("dl_"))
        #expect(name.hasSuffix(".mp4"))
    }

    @Test func downloadURLPrefersAudio() {
        #expect(DownloadLogic.downloadURL(audioUrl: "a", videoUrl: "v") == "a")
    }

    @Test func downloadURLFallsBackToVideo() {
        #expect(DownloadLogic.downloadURL(audioUrl: "", videoUrl: "v") == "v")
    }

    @Test func downloadURLNilWhenBothEmpty() {
        #expect(DownloadLogic.downloadURL(audioUrl: "", videoUrl: "") == nil)
    }

    @Test func downloadedItemRoundTrips() throws {
        let item = DownloadedItem(videoId: "v", title: "T", artist: "A", thumbnail: "th", duration: 42, fileName: "dl_v.mp4")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DownloadedItem.self, from: data)
        #expect(decoded == item)
        #expect(decoded.id == "v")
    }
}
