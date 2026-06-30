import Foundation

/// Pure, WebKit-free HTML → AttributedString conversion for Piped comment and
/// description markup. Preserves bold/italic emphasis and links, turns `<br>`
/// and block-closing tags into newlines, and decodes character entities.
///
/// Why not NSAttributedString(documentType: .html): that API parses via WebKit's
/// NSHTMLReader, which spins a *nested* CFRunLoop. Invoked from a SwiftUI
/// View.body during a List's UICollectionView layout pass, the re-entrant
/// runloop crashes the app (SIGABRT in _updateVisibleCellsNow:). This tokenizer
/// is plain string processing — safe to call while rendering, and unit-testable.
enum HTMLText {
    /// Rich text: `<b>`/`<strong>` → bold, `<i>`/`<em>` → italic, `<a href>` →
    /// link, `<br>` and closing block tags → newlines.
    static func attributed(_ html: String) -> AttributedString {
        var out = AttributedString()
        var bold = 0, italic = 0
        var links: [URL?] = []
        for token in HTMLTokenizer.tokens(in: html) {
            switch token {
            case .text(let raw):
                out.append(styledRun(decodeEntities(raw), bold: bold, italic: italic, link: links.compactMap { $0 }.last))
            case .lineBreak:
                out.append(AttributedString("\n"))
            case .open(let name, let tag):
                if name == "b" || name == "strong" { bold += 1 }
                else if name == "i" || name == "em" { italic += 1 }
                else if name == "a" { links.append(HTMLTokenizer.href(tag)) }
            case .close(let name):
                if name == "b" || name == "strong" { bold = max(0, bold - 1) }
                else if name == "i" || name == "em" { italic = max(0, italic - 1) }
                else if name == "a" { if !links.isEmpty { links.removeLast() } }
                else if name == "p" || name == "div" || name == "li" { out.append(AttributedString("\n")) }
            }
        }
        // Auto-link bare timestamps (pipe-seek://) and URLs the markup didn't
        // already wrap in <a>, so comments behave like the description.
        return DescriptionLinks.autoLinked(trimmed(out))
    }

    private static func styledRun(_ text: String, bold: Int, italic: Int, link: URL?) -> AttributedString {
        var run = AttributedString(text)
        var intent: InlinePresentationIntent = []
        if bold > 0 { intent.insert(.stronglyEmphasized) }
        if italic > 0 { intent.insert(.emphasized) }
        if !intent.isEmpty { run.inlinePresentationIntent = intent }
        if let link { run.link = link }
        return run
    }

    private static func trimmed(_ attr: AttributedString) -> AttributedString {
        var s = attr
        while let f = s.characters.first, f.isWhitespace { s.characters.removeFirst() }
        while let l = s.characters.last, l.isWhitespace { s.characters.removeLast() }
        return s
    }

    /// Decode named and numeric character references (decimal + hex).
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
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let full = Range(match.range, in: result),
                  let digits = Range(match.range(at: 1), in: result),
                  let code = UInt32(result[digits], radix: radix),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceSubrange(full, with: String(scalar))
        }
        return result
    }
}
