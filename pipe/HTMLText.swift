import Foundation

/// Pure, WebKit-free HTML → plain text conversion for Piped comment/description
/// markup (`<br>`, `<b>`, `<a href>`, character entities).
///
/// Why this exists: `NSAttributedString(data:options:[.documentType:.html])`
/// parses via WebKit's `NSHTMLReader`, which spins a *nested* `CFRunLoop`. When
/// invoked from a SwiftUI `View.body` during a `List`'s `UICollectionView`
/// layout pass, that re-entrant runloop crashes the app (SIGABRT inside
/// `_updateVisibleCellsNow:`). This converter is plain string processing, so it
/// is safe to call synchronously while rendering — and unit-testable.
enum HTMLText {
    /// Strip tags (turning block/break tags into newlines) and decode the common
    /// HTML entities, yielding display-ready plain text.
    static func plainText(_ html: String) -> String {
        let withBreaks = newlineTags.reduce(html) { acc, tag in
            acc.replacingOccurrences(of: tag, with: "\n", options: [.regularExpression, .caseInsensitive])
        }
        let stripped = withBreaks.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decodeEntities(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `<br>`, `<br/>`, `</p>`, `</div>`, `</li>` become line breaks so structure
    /// survives tag removal.
    private static let newlineTags = ["<br\\s*/?>", "</p>", "</div>", "</li>"]

    /// Decode named and numeric character references. Named set covers what
    /// Piped emits; numeric handles the long tail (decimal and hex).
    static func decodeEntities(_ text: String) -> String {
        var result = named.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        result = decodeNumeric(result, pattern: "&#([0-9]+);", radix: 10)
        result = decodeNumeric(result, pattern: "&#[xX]([0-9a-fA-F]+);", radix: 16)
        // `&amp;` last so it can't re-trigger the substitutions above.
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    private static let named: [String: String] = [
        "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
    ]

    private static func decodeNumeric(_ text: String, pattern: String, radix: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let full = Range(match.range, in: result),
                  let digits = Range(match.range(at: 1), in: result),
                  let code = UInt32(result[digits], radix: radix),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceSubrange(full, with: String(scalar))
        }
        return result
    }
}
