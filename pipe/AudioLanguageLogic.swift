import Foundation

/// Pure choice of which audio track to play on a multi-language (dubbed)
/// video. Without it the app picked by bitrate alone, and dubs share near-equal
/// bitrates, so a video could start in any language.
enum AudioLanguageLogic {
    /// Pseudo-language meaning "the uploader's own track, whatever it is".
    static let original = "original"
    /// Default preference, and the fallback when a video lacks the preference.
    static let english = "en"

    /// Settings choices: English and Original first, then the languages
    /// YouTube auto-dubs into, by name.
    static func settingsChoices(locale: Locale = .current) -> [String] {
        let dubs = ["ar", "bn", "de", "es", "fr", "hi", "id", "it", "ja", "ko", "pl",
                    "pt", "ru", "ta", "te", "th", "tr", "vi", "zh-Hans", "zh-Hant"]
        return [english, original] + dubs.sorted { displayName($0, locale: locale) < displayName($1, locale: locale) }
    }

    /// Whether a track tagged `locale` satisfies `language`. A bare language
    /// ("en") matches any regional variant ("en-US"); a qualified one
    /// ("zh-Hans") must match exactly, so Simplified never stands in for
    /// Traditional.
    static func matches(_ locale: String?, _ language: String) -> Bool {
        guard let locale else { return false }
        let tag = locale.lowercased(), wanted = language.lowercased()
        return tag == wanted || (!wanted.contains("-") && baseLanguage(tag) == wanted)
    }

    static func baseLanguage(_ tag: String) -> String {
        String(tag.split(separator: "-").first ?? "")
    }

    /// Tracks in `language` (or the original track for `original`). Audio
    /// description tracks are never chosen implicitly.
    static func tracks(_ all: [AudioStream], in language: String) -> [AudioStream] {
        if language == original { return all.filter { $0.audioTrackType == "ORIGINAL" } }
        return all.filter { matches($0.audioTrackLocale, language) && $0.audioTrackType != "DESCRIPTIVE" }
    }

    /// The preferred language's tracks, else English, else the original, else
    /// everything (an instance that doesn't label tracks). Restricted to
    /// MP4/M4A when any exist, since AVPlayer can't play WebM audio.
    static func candidates(_ all: [AudioStream], preferred: String) -> [AudioStream] {
        let mp4 = all.filter { $0.mimeType.contains("mp4") || $0.mimeType.contains("m4a") }
        let pool = mp4.isEmpty ? all : mp4
        for language in [preferred, english, original] {
            let match = tracks(pool, in: language)
            if !match.isEmpty { return match }
        }
        return pool
    }

    /// Highest-bitrate URL among the candidates; empty when there's no audio.
    static func bestURL(from all: [AudioStream], preferred: String) -> String {
        candidates(all, preferred: preferred).max { $0.bitrate < $1.bitrate }?.url ?? ""
    }

    /// The distinct languages a video offers, original first, then by name.
    /// Fewer than two means there's nothing to choose between.
    static func languages(in all: [AudioStream], locale: Locale = .current) -> [String] {
        let spoken = all.filter { $0.audioTrackType != "DESCRIPTIVE" }
        let originals = Set(spoken.filter { $0.audioTrackType == "ORIGINAL" }.compactMap(\.audioTrackLocale))
        let unique = Set(spoken.compactMap(\.audioTrackLocale))
        return unique.sorted { a, b in
            if originals.contains(a) != originals.contains(b) { return originals.contains(a) }
            return displayName(a, locale: locale) < displayName(b, locale: locale)
        }
    }

    /// Language of the track whose URL is `url`, if it's labeled.
    static func language(ofURL url: String?, in all: [AudioStream]) -> String? {
        all.first { $0.url == url }?.audioTrackLocale
    }

    /// The language actually playing: the track at `playingURL`, or — when that
    /// URL has since been re-minted and no longer appears in `all` — the track
    /// the `chosen` preference resolves to.
    static func activeLanguage(playingURL: String?, chosen: String, in all: [AudioStream]) -> String? {
        language(ofURL: playingURL, in: all) ?? language(ofURL: bestURL(from: all, preferred: chosen), in: all)
    }

    /// Human-readable name ("Spanish", "Chinese (Simplified)").
    static func displayName(_ code: String, locale: Locale = .current) -> String {
        if code == original { return "Original" }
        return locale.localizedString(forIdentifier: code) ?? code
    }
}
