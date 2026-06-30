import Testing
import Foundation
@testable import pipe

struct HTMLTextTests {
    /// Visible characters of the parsed AttributedString.
    private func text(_ html: String) -> String {
        String(HTMLText.attributed(html).characters)
    }

    @Test func stripsTagsKeepingText() {
        #expect(text("<b>Hello</b> <i>world</i>") == "Hello world")
    }

    @Test func boldRunIsStronglyEmphasized() {
        let attr = HTMLText.attributed("plain <b>bold</b>")
        let boldRun = attr.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(boldRun != nil)
        #expect(String(attr[boldRun!.range].characters) == "bold")
    }

    @Test func italicRunIsEmphasized() {
        let attr = HTMLText.attributed("a <em>b</em>")
        #expect(attr.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    }

    @Test func anchorBecomesLinkOnVisibleText() {
        let attr = HTMLText.attributed("see <a href=\"https://x.com\">my site</a>")
        #expect(String(attr.characters) == "see my site")
        let linkRun = attr.runs.first { $0.link != nil }
        #expect(linkRun?.link == URL(string: "https://x.com"))
        #expect(String(attr[linkRun!.range].characters) == "my site")
    }

    @Test func breakAndBlockTagsBecomeNewlines() {
        #expect(text("line one<br>line two") == "line one\nline two")
        #expect(text("a<br/>b<br />c") == "a\nb\nc")
        #expect(text("<p>one</p><p>two</p>") == "one\ntwo")
    }

    @Test func decodesNamedEntities() {
        #expect(text("Tom &amp; Jerry &lt;3 &quot;hi&quot;") == "Tom & Jerry <3 \"hi\"")
        #expect(text("a&nbsp;b") == "a b")
    }

    @Test func decodesNumericEntities() {
        #expect(text("it&#39;s") == "it's")
        #expect(text("don&#8217;t") == "don\u{2019}t")
        #expect(text("hi &#x1F600;") == "hi \u{1F600}")
    }

    @Test func ampersandDecodedLastSoItDoesNotRetrigger() {
        #expect(text("&amp;lt;") == "&lt;")
    }

    @Test func plainTextPassesThroughUnchanged() {
        #expect(text("just text") == "just text")
    }

    @Test func ignoresMalformedNumericEntity() {
        #expect(text("x &#999999999999; y") == "x &#999999999999; y")
    }

    @Test func nestedBoldItalicCombines() {
        let attr = HTMLText.attributed("<b><i>both</i></b>")
        let run = attr.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(run?.inlinePresentationIntent?.contains(.emphasized) == true)
    }
}
