import Foundation

/// Splits an HTML string into a flat token stream (text, line break, open/close
/// tag) using plain string scanning — no WebKit, no nested runloop. Pure and
/// unit-testable; `HTMLText` turns these tokens into a styled AttributedString.
enum HTMLToken: Equatable {
    case text(String)
    case lineBreak              // <br>, <br/>
    case open(name: String, tag: String)   // full tag kept so attrs (href) survive
    case close(name: String)
}

enum HTMLTokenizer {
    static func tokens(in html: String) -> [HTMLToken] {
        var tokens: [HTMLToken] = []
        var text = ""
        let scalars = Array(html)
        var i = 0
        while i < scalars.count {
            guard scalars[i] == "<", let end = nextIndex(of: ">", in: scalars, from: i) else {
                text.append(scalars[i]); i += 1; continue
            }
            if !text.isEmpty { tokens.append(.text(text)); text = "" }
            tokens.append(token(forTag: String(scalars[(i + 1)..<end])))
            i = end + 1
        }
        if !text.isEmpty { tokens.append(.text(text)) }
        return tokens
    }

    private static func nextIndex(of char: Character, in scalars: [Character], from: Int) -> Int? {
        var j = from + 1
        while j < scalars.count { if scalars[j] == char { return j }; j += 1 }
        return nil
    }

    /// Classify the inside of a `<...>` tag into a token.
    private static func token(forTag inner: String) -> HTMLToken {
        let trimmed = inner.trimmingCharacters(in: .whitespaces)
        let name = tagName(trimmed)
        if name == "br" { return .lineBreak }
        if trimmed.hasPrefix("/") { return .close(name: name) }
        return .open(name: name, tag: trimmed)
    }

    /// Lowercased element name from a tag body (`a href=...` → `a`, `/p` → `p`).
    static func tagName(_ tag: String) -> String {
        var s = Substring(tag)
        if s.hasPrefix("/") { s = s.dropFirst() }
        let name = s.prefix { !$0.isWhitespace && $0 != "/" }
        return name.lowercased()
    }

    /// Extract the href URL from an `<a ...>` open tag, if present and valid.
    static func href(_ tag: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: "href\\s*=\\s*[\"']([^\"']+)[\"']", options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let r = Range(match.range(at: 1), in: tag) else { return nil }
        return URL(string: String(tag[r]))
    }
}
