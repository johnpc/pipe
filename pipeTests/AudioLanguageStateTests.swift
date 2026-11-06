import Testing
import Foundation
@testable import pipe

private let dubbedStreams = [
    AudioStream(url: "https://x/en", bitrate: 129_000, mimeType: "audio/mp4",
                audioTrackLocale: "en", audioTrackType: "ORIGINAL"),
    AudioStream(url: "https://x/es", bitrate: 129_400, mimeType: "audio/mp4",
                audioTrackLocale: "es", audioTrackType: "DUBBED"),
]

/// Settings persistence, the player's per-item switch, and the wire/disk
/// formats that carry the audio language.
@MainActor
struct AudioLanguageStateTests {

    private func suite() -> UserDefaults { UserDefaults(suiteName: "lang-\(UUID().uuidString)")! }

    // MARK: - Settings

    @Test func settingsDefaultToEnglish() {
        let s = AppSettings(defaults: suite())
        #expect(s.audioLanguage == "en")
    }

    @Test func settingsPersistAndSyncGlobal() {
        let defaults = suite()
        let s1 = AppSettings(defaults: defaults)
        s1.audioLanguage = "fr"
        #expect(pipedAudioLanguage == "fr")
        #expect(AppSettings(defaults: defaults).audioLanguage == "fr")
        pipedAudioLanguage = AudioLanguageLogic.english
    }

    // MARK: - Player

    private func playerWithItem() -> PlayerState {
        let player = isolatedPlayer()
        player.addToQueue(videoId: "v", url: "bad://video", audioUrl: "https://x/en",
                          title: "T", artist: "a", thumbnail: "", duration: 100)
        return player
    }

    @Test func selectingLanguageSwapsTrackAndRemembersChoice() {
        let player = playerWithItem()
        player.selectAudioLanguage("es", from: dubbedStreams)
        #expect(player.currentAudioURL == "https://x/es")
        #expect(player.queue[0].audioLanguage == "es")
        #expect(player.currentAudioLanguageChoice == "es")
    }

    @Test func selectingLanguageKeepsPosition() {
        let player = playerWithItem()
        player.handleProgress(currentTime: 42, itemDuration: 100)
        player.selectAudioLanguage("es", from: dubbedStreams)
        #expect(player.currentTime == 42)
    }

    @Test func selectingLanguageInVideoModeStoresChoiceOnly() {
        let player = playerWithItem()
        player.toggleVideoMode()
        player.selectAudioLanguage("es", from: dubbedStreams)
        #expect(player.queue[0].audioUrl == "https://x/es")
        #expect(player.videoMode)
    }

    @Test func selectingLanguageWithoutStreamsIsNoOp() {
        let player = playerWithItem()
        player.selectAudioLanguage("es", from: [])
        #expect(player.currentAudioURL == "https://x/en")
        #expect(player.queue[0].audioLanguage == nil)
    }

    @Test func noCurrentItemFallsBackToSettingsChoice() {
        let player = isolatedPlayer()
        player.selectAudioLanguage("es", from: dubbedStreams)
        #expect(player.currentAudioURL == nil)
        #expect(player.currentAudioLanguageChoice == pipedAudioLanguage)
    }

    // MARK: - Formats

    @Test func queueItemRoundTripsAudioLanguage() throws {
        var item = QueueItem(videoId: "v", title: "T", artist: "A", thumbnail: "", url: "u",
                             audioUrl: "au", duration: 1, uploadedDate: nil)
        item.audioLanguage = "ja"
        let decoded = try JSONDecoder().decode(QueueItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.audioLanguage == "ja")
    }

    @Test func legacyQueueItemDecodesWithoutAudioLanguage() throws {
        let json = #"{"videoId":"v","title":"T","artist":"A","thumbnail":"","url":"u","audioUrl":"","duration":1}"#
        let decoded = try JSONDecoder().decode(QueueItem.self, from: Data(json.utf8))
        #expect(decoded.audioLanguage == nil)
    }

    @Test func audioStreamDecodesPipedTrackFields() throws {
        let json = #"{"url":"u","bitrate":1,"mimeType":"audio/mp4","audioTrackLocale":"es","audioTrackType":"DUBBED","audioTrackName":"Spanish"}"#
        let decoded = try JSONDecoder().decode(AudioStream.self, from: Data(json.utf8))
        #expect(decoded.audioTrackLocale == "es")
        #expect(decoded.audioTrackType == "DUBBED")
    }

    @Test func audioStreamDecodesWithoutTrackFields() throws {
        let json = #"{"url":"u","bitrate":1,"mimeType":"audio/mp4"}"#
        let decoded = try JSONDecoder().decode(AudioStream.self, from: Data(json.utf8))
        #expect(decoded.audioTrackLocale == nil)
    }
}
