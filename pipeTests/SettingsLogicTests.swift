import Testing
@testable import pipe

struct SettingsLogicTests {

    // MARK: - normalizedInstance

    @Test func addsHttpsSchemeWhenMissing() {
        #expect(SettingsLogic.normalizedInstance("pipedapi.example.com") == "https://pipedapi.example.com")
    }

    @Test func keepsExistingScheme() {
        #expect(SettingsLogic.normalizedInstance("http://local.test") == "http://local.test")
        #expect(SettingsLogic.normalizedInstance("https://x.test") == "https://x.test")
    }

    @Test func trimsWhitespaceAndTrailingSlashes() {
        #expect(SettingsLogic.normalizedInstance("  https://x.test/  ") == "https://x.test")
        #expect(SettingsLogic.normalizedInstance("https://x.test///") == "https://x.test")
    }

    @Test func blankFallsBackToDefault() {
        #expect(SettingsLogic.normalizedInstance("   ") == AppSettings.defaultInstance)
        #expect(SettingsLogic.normalizedInstance("") == AppSettings.defaultInstance)
    }

    // MARK: - isValidInstanceDraft

    @Test func validDraftHasHost() {
        #expect(SettingsLogic.isValidInstanceDraft("pipedapi.example.com") == true)
        #expect(SettingsLogic.isValidInstanceDraft("https://x.test") == true)
    }

    @Test func invalidDraftRejected() {
        #expect(SettingsLogic.isValidInstanceDraft("") == false)
        #expect(SettingsLogic.isValidInstanceDraft("   ") == false)
    }

    // MARK: - addingSearch

    @Test func insertsAtFront() {
        let result = SettingsLogic.addingSearch("new", to: ["old"], max: 10)
        #expect(result == ["new", "old"])
    }

    @Test func dedupesCaseInsensitivelyMovingToFront() {
        let result = SettingsLogic.addingSearch("Jazz", to: ["lofi", "jazz", "rock"], max: 10)
        #expect(result == ["Jazz", "lofi", "rock"])
    }

    @Test func capsAtMax() {
        let result = SettingsLogic.addingSearch("x", to: ["a", "b", "c"], max: 3)
        #expect(result == ["x", "a", "b"])
    }

    @Test func ignoresBlankTerm() {
        #expect(SettingsLogic.addingSearch("   ", to: ["a"], max: 10) == ["a"])
    }

    @Test func trimsStoredTerm() {
        #expect(SettingsLogic.addingSearch("  hello  ", to: [], max: 10) == ["hello"])
    }
}
