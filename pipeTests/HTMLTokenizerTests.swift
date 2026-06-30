import Testing
import Foundation
@testable import pipe

struct HTMLTokenizerTests {
    @Test func plainTextIsSingleTextToken() {
        #expect(HTMLTokenizer.tokens(in: "hello") == [.text("hello")])
    }

    @Test func splitsTextAroundTags() {
        #expect(HTMLTokenizer.tokens(in: "a<b>x</b>c") ==
                [.text("a"), .open(name: "b", tag: "b"), .text("x"), .close(name: "b"), .text("c")])
    }

    @Test func brVariantsAreLineBreaks() {
        #expect(HTMLTokenizer.tokens(in: "<br><br/><br />") == [.lineBreak, .lineBreak, .lineBreak])
    }

    @Test func openTagRetainsAttributesForHref() {
        let tokens = HTMLTokenizer.tokens(in: "<a href=\"https://x.com\">hi</a>")
        guard case let .open(name, tag) = tokens.first else { Issue.record("expected open tag"); return }
        #expect(name == "a")
        #expect(HTMLTokenizer.href(tag) == URL(string: "https://x.com"))
    }

    @Test func unclosedAngleBracketIsLiteralText() {
        // No closing '>' → treat '<' as literal so we never drop content.
        #expect(HTMLTokenizer.tokens(in: "2 < 3") == [.text("2 < 3")])
    }

    @Test func tagNameLowercasesAndStripsSlash() {
        #expect(HTMLTokenizer.tagName("A HREF=x") == "a")
        #expect(HTMLTokenizer.tagName("/P") == "p")
    }

    @Test func hrefMissingReturnsNil() {
        #expect(HTMLTokenizer.href("a") == nil)
    }
}
