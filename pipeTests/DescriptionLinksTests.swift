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
}
