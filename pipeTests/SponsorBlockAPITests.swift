import Testing
import Foundation
@testable import pipe

/// Pure URL-builder coverage. The session-mutating decode tests live in the
/// serialized `PipedAPITests` suite to avoid racing on the shared `PipedAPI.session`.
struct SponsorBlockAPITests {
    @Test func urlIncludesVideoIdAndCategories() {
        let url = PipedAPI.sponsorSegmentsURL("abc123")
        #expect(url?.absoluteString.contains("videoID=abc123") == true)
        #expect(url?.absoluteString.contains("category=sponsor") == true)
        #expect(url?.absoluteString.hasPrefix(PipedAPI.sponsorBlockBase) == true)
    }
}
