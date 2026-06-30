import Testing
import Foundation
@testable import pipe

struct DescriptionLinksTests {
    @Test func parsesMinuteSecondTimestamp() {
        #expect(DescriptionLinks.seconds(fromTimestamp: "1:23") == 83)
        #expect(DescriptionLinks.seconds(fromTimestamp: "0:05") == 5)
    }

    @Test func parsesHourMinuteSecondTimestamp() {
        #expect(DescriptionLinks.seconds(fromTimestamp: "1:02:03") == 3723)
    }

    @Test func rejectsNonTimestamps() {
        #expect(DescriptionLinks.seconds(fromTimestamp: "12") == nil)
        #expect(DescriptionLinks.seconds(fromTimestamp: "1:99") == nil)   // seconds ≥ 60
        #expect(DescriptionLinks.seconds(fromTimestamp: "abc") == nil)
    }

    @Test func seekSecondsFromURL() {
        #expect(DescriptionLinks.seekSeconds(from: URL(string: "pipe-seek://90")!) == 90)
        #expect(DescriptionLinks.seekSeconds(from: URL(string: "https://example.com")!) == nil)
    }

    @Test func attributedAddsTimestampLink() {
        let attr = DescriptionLinks.attributed("Intro at 0:30 then more")
        // The "0:30" run should carry a pipe-seek link.
        let hasSeekLink = attr.runs.contains { $0.link?.scheme == DescriptionLinks.seekScheme }
        #expect(hasSeekLink)
    }

    @Test func attributedAddsWebLink() {
        let attr = DescriptionLinks.attributed("See https://example.com for more")
        let hasWebLink = attr.runs.contains { $0.link?.host?.contains("example.com") == true }
        #expect(hasWebLink)
    }

    @Test func autoLinkedPreservesExistingLinks() {
        // A run already carrying an <a href> link must not be overwritten by the
        // bare-URL/timestamp auto-linker.
        var styled = AttributedString("watch 0:30")
        if let r = styled.range(of: "0:30") { styled[r].link = URL(string: "https://manual.example") }
        let result = DescriptionLinks.autoLinked(styled)
        let run = result.runs.first { String(result[$0.range].characters).contains("0:30") }
        #expect(run?.link == URL(string: "https://manual.example"))
    }

    @Test func autoLinkedAddsSeekToBareTimestamp() {
        let result = DescriptionLinks.autoLinked(AttributedString("jump to 2:00"))
        #expect(result.runs.contains { $0.link?.scheme == DescriptionLinks.seekScheme })
    }
}
