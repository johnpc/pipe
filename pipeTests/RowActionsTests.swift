import Testing
import Foundation
@testable import pipe

struct RowActionsTests {
    @Test func youtubeURLBuildsWatchLink() {
        #expect(RowActions.youtubeURL(videoId: "abc123")?.absoluteString == "https://youtube.com/watch?v=abc123")
    }

    @Test func youtubeURLNilForBlank() {
        #expect(RowActions.youtubeURL(videoId: "") == nil)
        #expect(RowActions.youtubeURL(videoId: "   ") == nil)
    }

    @Test func channelURLBuildsChannelLink() {
        #expect(RowActions.youtubeChannelURL(channelId: "UC123")?.absoluteString == "https://youtube.com/channel/UC123")
    }

    @Test func channelURLNilForBlank() {
        #expect(RowActions.youtubeChannelURL(channelId: "") == nil)
    }
}
