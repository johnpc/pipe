import Testing
import Foundation
@testable import pipe

struct SearchLogicTests {
    private func stream(_ uploader: String?) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(UUID().uuidString)", title: "t", thumbnail: "", duration: 1,
                      uploaderName: uploader, uploadedDate: nil, uploaded: nil)
    }

    @Test func channelSuggestionsAreTrendingUploadersDedupedInOrder() {
        let trending = [stream("A"), stream("B"), stream("A"), stream(" C "), stream(nil), stream("")]
        #expect(SearchLogic.channelSuggestions(from: trending) == ["A", "B", "C"])
    }

    @Test func channelSuggestionsAreCapped() {
        let trending = (0..<20).map { stream("Channel \($0)") }
        #expect(SearchLogic.channelSuggestions(from: trending).count == SearchLogic.maxSuggestions)
        #expect(SearchLogic.channelSuggestions(from: trending, limit: 2) == ["Channel 0", "Channel 1"])
        #expect(SearchLogic.channelSuggestions(from: []).isEmpty)
    }

    @Test func isSubmittableRejectsEmptyAndWhitespace() {
        #expect(SearchLogic.isSubmittable("") == false)
        #expect(SearchLogic.isSubmittable("   ") == false)
        #expect(SearchLogic.isSubmittable("\n\t") == false)
    }

    @Test func isSubmittableAcceptsRealQuery() {
        #expect(SearchLogic.isSubmittable("cats") == true)
        #expect(SearchLogic.isSubmittable("  cats  ") == true)
    }

    @Test func shouldAutoSearchNeedsMinLength() {
        #expect(SearchLogic.shouldAutoSearch("") == false)
        #expect(SearchLogic.shouldAutoSearch("a") == false)
        #expect(SearchLogic.shouldAutoSearch("ab") == true)
        #expect(SearchLogic.shouldAutoSearch("  a  ") == false) // trims first
        #expect(SearchLogic.shouldAutoSearch("cats") == true)
    }
}
