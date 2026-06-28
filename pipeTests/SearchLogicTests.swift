import Testing
@testable import pipe

struct SearchLogicTests {
    @Test func suggestionsAreNonEmptyAndUnique() {
        #expect(!SearchLogic.suggestions.isEmpty)
        #expect(Set(SearchLogic.suggestions).count == SearchLogic.suggestions.count)
    }

    @Test func suggestionsContainKnownChannel() {
        #expect(SearchLogic.suggestions.contains("MrBeast"))
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
