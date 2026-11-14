import Foundation

/// The parts of a YouTube HLS master playlist the app chooses from: the audio
/// renditions (one per language per quality group) and the variants that
/// reference them. YouTube serves these for every video — including ones whose
/// direct googlevideo URLs it has stopped honoring — so they are the durable
/// way to play. Pure, so the choice rules are unit-tested on captured text.
struct HLSMaster: Equatable {
    struct AudioRendition: Equatable {
        let groupId: String
        let language: String?
        let name: String
        let isDefault: Bool
        let uri: URL
        /// YouTube labels the uploader's own track "… - original".
        var isOriginal: Bool { name.lowercased().contains("original") }
    }

    struct Variant: Equatable {
        let bandwidth: Int
        let audioGroup: String?
    }

    let renditions: [AudioRendition]
    let variants: [Variant]

    static func parse(_ text: String, relativeTo base: URL) -> HLSMaster {
        var renditions: [AudioRendition] = []
        var variants: [Variant] = []
        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("#EXT-X-MEDIA:") {
                let attrs = attributes(String(line.dropFirst("#EXT-X-MEDIA:".count)))
                guard attrs["TYPE"] == "AUDIO", let group = attrs["GROUP-ID"],
                      let raw = attrs["URI"], let uri = URL(string: raw, relativeTo: base)?.absoluteURL else { continue }
                renditions.append(AudioRendition(groupId: group, language: attrs["LANGUAGE"], name: attrs["NAME"] ?? "",
                                                 isDefault: attrs["DEFAULT"] == "YES", uri: uri))
            } else if line.hasPrefix("#EXT-X-STREAM-INF:") {
                let attrs = attributes(String(line.dropFirst("#EXT-X-STREAM-INF:".count)))
                variants.append(Variant(bandwidth: Int(attrs["BANDWIDTH"] ?? "") ?? 0, audioGroup: attrs["AUDIO"]))
            }
        }
        return HLSMaster(renditions: renditions, variants: variants)
    }

    /// `KEY=value,KEY="quoted, value"` → dictionary; quotes are stripped.
    static func attributes(_ list: String) -> [String: String] {
        var out: [String: String] = [:]
        var key = "", value = "", inQuotes = false, readingValue = false
        func flush() {
            if !key.isEmpty { out[key] = value }
            key = ""; value = ""; readingValue = false
        }
        for ch in list {
            switch (ch, inQuotes, readingValue) {
            case ("\"", _, true): inQuotes.toggle()
            case (",", false, _): flush()
            case ("=", false, false): readingValue = true
            default: if readingValue { value.append(ch) } else { key.append(ch) }
            }
        }
        flush()
        return out
    }

    /// The audio group of the highest-bandwidth variant: YouTube pairs its best
    /// video with its best audio group (e.g. "234" = 128 kbps AAC over "233").
    var bestAudioGroup: String? {
        variants.max { $0.bandwidth < $1.bandwidth }?.audioGroup
    }
}
