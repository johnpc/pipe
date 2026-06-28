import Foundation

/// Parses a video description into an AttributedString where timestamps (e.g.
/// "1:23", "1:02:03") become tappable links to a custom `pipe-seek://<seconds>`
/// scheme, and plain URLs become tappable web links. Pure + testable.
enum DescriptionLinks {
    static let seekScheme = "pipe-seek"

    /// Seconds encoded in a `pipe-seek://<seconds>` URL, or nil if not one.
    static func seekSeconds(from url: URL) -> Double? {
        guard url.scheme == seekScheme else { return nil }
        let raw = url.host ?? url.absoluteString.replacingOccurrences(of: "\(seekScheme)://", with: "")
        return Double(raw)
    }

    /// Parse "h:mm:ss" or "m:ss" into total seconds, or nil if not a timestamp.
    static func seconds(fromTimestamp text: String) -> Int? {
        let parts = text.split(separator: ":").map(String.init)
        guard (2...3).contains(parts.count) else { return nil }
        var total = 0
        for part in parts {
            guard part.count <= 2 || part == parts.first, let n = Int(part), n >= 0 else { return nil }
            total = total * 60 + n
        }
        // Minutes/seconds segments must be < 60 (first segment may be larger).
        for part in parts.dropFirst() where (Int(part) ?? 60) >= 60 { return nil }
        return total
    }

    /// Build an AttributedString with timestamp + URL links applied.
    static func attributed(_ description: String) -> AttributedString {
        var result = AttributedString(description)
        applyTimestamps(&result, in: description)
        applyURLs(&result, in: description)
        return result
    }

    private static func applyTimestamps(_ attr: inout AttributedString, in source: String) {
        let pattern = #"\b\d{1,2}(:\d{2}){1,2}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            guard let r = Range(match.range, in: source),
                  let secs = seconds(fromTimestamp: String(source[r])),
                  let ar = attr.range(of: String(source[r])) else { continue }
            attr[ar].link = URL(string: "\(seekScheme)://\(secs)")
        }
    }

    private static func applyURLs(_ attr: inout AttributedString, in source: String) {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        detector?.matches(in: source, range: NSRange(source.startIndex..., in: source)).forEach { m in
            guard let url = m.url, let r = Range(m.range, in: source),
                  let ar = attr.range(of: String(source[r])) else { return }
            attr[ar].link = url
        }
    }
}
