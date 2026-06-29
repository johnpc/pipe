import Testing
import Foundation
@testable import pipe

@MainActor
struct AppSettingsTests {

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "settings-\(UUID().uuidString)")!)
    }

    @Test func defaultsToConfiguredInstance() {
        let s = makeSettings()
        #expect(s.instanceURL == AppSettings.defaultInstance)
    }

    @Test func settingInstanceUpdatesPipedBase() {
        let s = makeSettings()
        s.instanceURL = "custom.piped.test"
        #expect(pipedBase == "https://custom.piped.test")
        // Restore so other tests aren't affected by the global.
        pipedBase = AppSettings.defaultInstance
    }

    @Test func resetInstanceRestoresDefault() {
        let s = makeSettings()
        s.instanceURL = "https://other.test"
        s.resetInstance()
        #expect(s.instanceURL == AppSettings.defaultInstance)
        pipedBase = AppSettings.defaultInstance
    }

    @Test func recordSearchAddsToHistory() {
        let s = makeSettings()
        s.recordSearch("cats")
        s.recordSearch("dogs")
        #expect(s.searchHistory == ["dogs", "cats"])
    }

    @Test func recordSearchIgnoresBlank() {
        let s = makeSettings()
        s.recordSearch("   ")
        #expect(s.searchHistory.isEmpty)
    }

    @Test func clearHistoryEmptiesIt() {
        let s = makeSettings()
        s.recordSearch("cats")
        s.clearHistory()
        #expect(s.searchHistory.isEmpty)
    }

    @Test func historyPersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "settings-persist-\(UUID().uuidString)")!
        let s1 = AppSettings(defaults: suite)
        s1.recordSearch("persisted")
        let s2 = AppSettings(defaults: suite)
        #expect(s2.searchHistory == ["persisted"])
    }

    @Test func instancePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "settings-inst-\(UUID().uuidString)")!
        let s1 = AppSettings(defaults: suite)
        s1.instanceURL = "https://saved.test"
        let s2 = AppSettings(defaults: suite)
        #expect(s2.instanceURL == "https://saved.test")
        pipedBase = AppSettings.defaultInstance
    }

    @Test func offlineModeDefaultsOff() {
        #expect(makeSettings().offlineMode == false)
    }

    @Test func offlineModePersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "settings-offline-\(UUID().uuidString)")!
        let s1 = AppSettings(defaults: suite)
        s1.offlineMode = true
        let s2 = AppSettings(defaults: suite)
        #expect(s2.offlineMode == true)
    }
}
