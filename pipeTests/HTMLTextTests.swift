import Testing
@testable import pipe

struct HTMLTextTests {
    @Test func stripsTags() {
        #expect(HTMLText.plainText("<b>Hello</b> <i>world</i>") == "Hello world")
    }

    @Test func anchorTagLeavesVisibleText() {
        #expect(HTMLText.plainText("see <a href=\"https://x.com\">my site</a>") == "see my site")
    }

    @Test func breakAndBlockTagsBecomeNewlines() {
        #expect(HTMLText.plainText("line one<br>line two") == "line one\nline two")
        #expect(HTMLText.plainText("a<br/>b<br />c") == "a\nb\nc")
        #expect(HTMLText.plainText("<p>one</p><p>two</p>") == "one\ntwo")
    }

    @Test func decodesNamedEntities() {
        #expect(HTMLText.plainText("Tom &amp; Jerry &lt;3 &quot;hi&quot;") == "Tom & Jerry <3 \"hi\"")
        #expect(HTMLText.plainText("a&nbsp;b") == "a b")
    }

    @Test func decodesNumericEntities() {
        // &#39; apostrophe, &#8217; right single quote, hex &#x1F600; emoji.
        #expect(HTMLText.plainText("it&#39;s") == "it's")
        #expect(HTMLText.plainText("don&#8217;t") == "don\u{2019}t")
        #expect(HTMLText.plainText("hi &#x1F600;") == "hi \u{1F600}")
    }

    @Test func ampersandDecodedLastSoItDoesNotRetrigger() {
        // "&amp;lt;" must become "&lt;" (literal), not "<".
        #expect(HTMLText.plainText("&amp;lt;") == "&lt;")
    }

    @Test func plainTextPassesThroughUnchanged() {
        #expect(HTMLText.plainText("just text") == "just text")
    }

    @Test func ignoresMalformedNumericEntity() {
        // Out-of-range scalar is left as-is rather than crashing.
        #expect(HTMLText.plainText("x &#999999999999; y") == "x &#999999999999; y")
    }
}
