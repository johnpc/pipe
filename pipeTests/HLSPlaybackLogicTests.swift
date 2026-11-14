import Testing
import Foundation
@testable import pipe

struct HLSPlaybackLogicTests {
    private func item(hls: String) -> QueueItem {
        QueueItem(videoId: "v", title: "t", artist: "a", thumbnail: "", url: "https://x/muxed.mp4", audioUrl: "https://x/a.m4a", hlsUrl: hls, duration: 10, uploadedDate: nil)
    }

    @Test func hlsIsUsedForStreamedItemsThatHaveOne() {
        #expect(HLSPlaybackLogic.usesHLS(item(hls: "https://m/master.m3u8"), isLocal: false))
        #expect(!HLSPlaybackLogic.usesHLS(item(hls: "https://m/master.m3u8"), isLocal: true))
        #expect(!HLSPlaybackLogic.usesHLS(item(hls: ""), isLocal: false))
    }

    @Test func audioSelectionMatchesPreferredThenEnglish() {
        let tags: [String?] = ["es-US", "en-US", nil, "de-DE"]
        #expect(HLSPlaybackLogic.audioSelection(tags: tags, preferred: "de") == 3)
        #expect(HLSPlaybackLogic.audioSelection(tags: tags, preferred: "fr") == 1)  // English fallback
        #expect(HLSPlaybackLogic.audioSelection(tags: ["fr", "de"], preferred: "it") == nil)
        #expect(HLSPlaybackLogic.audioSelection(tags: tags, preferred: AudioLanguageLogic.original) == 1)
    }

    @Test func queueItemWithoutHLSDecodesToEmpty() throws {
        let legacy = """
        {"videoId":"v","title":"t","artist":"a","thumbnail":"","url":"u","audioUrl":"","duration":1}
        """
        let decoded = try JSONDecoder().decode(QueueItem.self, from: Data(legacy.utf8))
        #expect(decoded.hlsUrl == "")
        let roundTrip = try JSONDecoder().decode(QueueItem.self, from: JSONEncoder().encode(item(hls: "https://m/x")))
        #expect(roundTrip.hlsUrl == "https://m/x")
    }

    @Test func castFallsBackToHLSWhenThereIsNoMuxedStream() {
        var it = item(hls: "https://m/master.m3u8")
        #expect(it.castPlaybackURL == "https://x/muxed.mp4")
        it.url = ""
        #expect(it.castPlaybackURL == "https://m/master.m3u8")
    }
}
