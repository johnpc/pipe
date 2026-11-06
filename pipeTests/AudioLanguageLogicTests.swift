import Testing
import Foundation
@testable import pipe

private func track(_ url: String, _ locale: String?, _ type: String? = "DUBBED",
                   bitrate: Int = 128_000, mime: String = "audio/mp4") -> AudioStream {
    AudioStream(url: url, bitrate: bitrate, mimeType: mime, audioTrackLocale: locale, audioTrackType: type)
}

private let usEnglish = Locale(identifier: "en_US")

/// A dubbed video the way the instance serves it: the original in English
/// plus dubs at near-identical bitrates (Spanish slightly higher, which is
/// exactly what used to win).
private let dubbed = [
    track("en", "en", "ORIGINAL", bitrate: 129_000),
    track("es", "es", bitrate: 129_400),
    track("fr", "fr", bitrate: 129_100),
    track("ad", "en", "DESCRIPTIVE", bitrate: 130_000),
]

struct AudioLanguageLogicTests {

    @Test func bareLanguageMatchesRegionalVariant() {
        #expect(AudioLanguageLogic.matches("en-US", "en"))
        #expect(AudioLanguageLogic.matches("EN", "en"))
        #expect(!AudioLanguageLogic.matches("es", "en"))
        #expect(!AudioLanguageLogic.matches(nil, "en"))
    }

    @Test func qualifiedLanguageMatchesExactly() {
        #expect(AudioLanguageLogic.matches("zh-Hans", "zh-Hans"))
        #expect(!AudioLanguageLogic.matches("zh-Hant", "zh-Hans"))
    }

    @Test func picksPreferredLanguageOverHigherBitrateDub() {
        #expect(AudioLanguageLogic.bestURL(from: dubbed, preferred: "en") == "en")
        #expect(AudioLanguageLogic.bestURL(from: dubbed, preferred: "fr") == "fr")
    }

    @Test func fallsBackToEnglishWhenPreferenceMissing() {
        #expect(AudioLanguageLogic.bestURL(from: dubbed, preferred: "ja") == "en")
    }

    @Test func fallsBackToOriginalWhenNoEnglish() {
        let tracks = [track("de", "de", "ORIGINAL"), track("es", "es", bitrate: 200_000)]
        #expect(AudioLanguageLogic.bestURL(from: tracks, preferred: "ja") == "de")
    }

    @Test func originalPreferenceKeepsUploadersTrack() {
        let tracks = [track("de", "de", "ORIGINAL"), track("en", "en", bitrate: 200_000)]
        #expect(AudioLanguageLogic.bestURL(from: tracks, preferred: AudioLanguageLogic.original) == "de")
    }

    @Test func neverPicksAudioDescriptionImplicitly() {
        let tracks = [track("ad", "en", "DESCRIPTIVE", bitrate: 999_000), track("en", "en", "ORIGINAL")]
        #expect(AudioLanguageLogic.bestURL(from: tracks, preferred: "en") == "en")
    }

    @Test func unlabeledTracksKeepHighestBitrateBehavior() {
        let tracks = [track("lo", nil, nil, bitrate: 64_000), track("hi", nil, nil, bitrate: 160_000)]
        #expect(AudioLanguageLogic.bestURL(from: tracks, preferred: "en") == "hi")
    }

    @Test func prefersPlayableMp4OverWebmInPreferredLanguage() {
        let tracks = [track("es-webm", "es", mime: "audio/webm"), track("en", "en", "ORIGINAL")]
        #expect(AudioLanguageLogic.bestURL(from: tracks, preferred: "es") == "en")
    }

    @Test func emptyWhenNoAudio() {
        #expect(AudioLanguageLogic.bestURL(from: [], preferred: "en") == "")
    }

    @Test func languagesListOriginalFirstThenByName() {
        #expect(AudioLanguageLogic.languages(in: dubbed, locale: usEnglish) == ["en", "fr", "es"])
    }

    @Test func singleLanguageVideoOffersNoChoice() {
        #expect(AudioLanguageLogic.languages(in: [track("en", "en", "ORIGINAL")]).count == 1)
        #expect(AudioLanguageLogic.languages(in: [track("x", nil, nil)]).isEmpty)
    }

    @Test func languageOfURLFindsTrackLocale() {
        #expect(AudioLanguageLogic.language(ofURL: "es", in: dubbed) == "es")
        #expect(AudioLanguageLogic.language(ofURL: "missing", in: dubbed) == nil)
    }

    @Test func activeLanguageUsesPlayingURLThenChoice() {
        #expect(AudioLanguageLogic.activeLanguage(playingURL: "fr", chosen: "en", in: dubbed) == "fr")
        #expect(AudioLanguageLogic.activeLanguage(playingURL: "re-minted", chosen: "es", in: dubbed) == "es")
        #expect(AudioLanguageLogic.activeLanguage(playingURL: nil, chosen: "en", in: []) == nil)
    }

    @Test func displayNames() {
        #expect(AudioLanguageLogic.displayName("es", locale: usEnglish) == "Spanish")
        #expect(AudioLanguageLogic.displayName(AudioLanguageLogic.original, locale: usEnglish) == "Original")
    }

    @Test func settingsChoicesStartWithEnglishThenOriginal() {
        let choices = AudioLanguageLogic.settingsChoices(locale: usEnglish)
        #expect(Array(choices.prefix(2)) == ["en", AudioLanguageLogic.original])
        #expect(choices.contains("zh-Hans"))
        #expect(Set(choices).count == choices.count)
    }
}
