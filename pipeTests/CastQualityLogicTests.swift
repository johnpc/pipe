import Testing
import Foundation
@testable import pipe

struct CastQualityLogicTests {

    private func stream(_ quality: String, videoOnly: Bool = false, mime: String = "video/mp4") -> VideoStream {
        VideoStream(url: "u-\(quality)", quality: quality, mimeType: mime, videoOnly: videoOnly)
    }

    // MARK: - height parsing

    @Test func parsesHeightFromQualityString() {
        #expect(CastQualityLogic.height(from: "1080p") == 1080)
        #expect(CastQualityLogic.height(from: "360p60") == 360)
        #expect(CastQualityLogic.height(from: "LBRY") == nil)
    }

    // MARK: - selection

    @Test func autoPicksHighestProgressive() {
        let streams = [stream("360p"), stream("1080p"), stream("720p")]
        #expect(CastQualityLogic.bestURL(from: streams, quality: .auto) == "u-1080p")
    }

    @Test func capSelectsHighestAtOrBelow() {
        let streams = [stream("360p"), stream("1080p"), stream("720p")]
        #expect(CastQualityLogic.bestURL(from: streams, quality: .p720) == "u-720p")
        #expect(CastQualityLogic.bestURL(from: streams, quality: .p360) == "u-360p")
    }

    @Test func capBelowEverythingFallsBackToLowest() {
        // Cap 360 but only 720/1080 offered → fall back to the lowest so casting
        // still works rather than returning nothing.
        let streams = [stream("1080p"), stream("720p")]
        #expect(CastQualityLogic.bestURL(from: streams, quality: .p360) == "u-720p")
    }

    @Test func ignoresVideoOnlyAndNonMp4() {
        let streams = [stream("1080p", videoOnly: true), stream("720p", mime: "video/webm"), stream("360p")]
        // Only the 360p progressive MP4 qualifies.
        #expect(CastQualityLogic.bestURL(from: streams, quality: .auto) == "u-360p")
    }

    @Test func emptyWhenNoProgressiveMp4() {
        let streams = [stream("1080p", videoOnly: true)]
        #expect(CastQualityLogic.bestURL(from: streams, quality: .auto) == "")
    }
}
