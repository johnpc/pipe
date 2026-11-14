import Foundation

/// Which audio rendition to play for a language preference. Mirrors
/// `AudioLanguageLogic`: the preferred language, else English, else the
/// original track, else whatever comes first — all within the best quality group.
extension HLSMaster {
    func audioRendition(preferred: String) -> AudioRendition? {
        let group = bestAudioGroup
        let pool = renditions.filter { group == nil || $0.groupId == group }
        guard !pool.isEmpty else { return renditions.first }
        for language in [preferred, AudioLanguageLogic.english, AudioLanguageLogic.original] {
            if let match = Self.rendition(pool, in: language) { return match }
        }
        return pool.first { $0.isDefault } ?? pool.first
    }

    /// First rendition in `language`; `original` means the uploader's own track.
    /// A bare language ("en") matches regional tags ("en-US") and vice versa.
    static func rendition(_ pool: [AudioRendition], in language: String) -> AudioRendition? {
        if language == AudioLanguageLogic.original { return pool.first { $0.isOriginal } }
        return pool.first { AudioLanguageLogic.matches($0.language, language) }
    }
}
