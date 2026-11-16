import Testing
import Foundation
@testable import pipe

@MainActor
struct AppSettingsTests {

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "settings-\(UUID().uuidString)")!)
    }

    @Test func freshInstallStartsOnTheDemoLibrary() {
        let s = makeSettings()
        #expect(s.instanceURL == AppSettings.defaultInstance)
        pipedBase = AppSettings.defaultInstance
    }

    @Test func anUpgradedInstallKeepsTheInstanceItWasUsing() {
        // Before the demo default existed the instance key was never written;
        // the presence of any app data proves the install predates it.
        let suite = UserDefaults(suiteName: "settings-\(UUID().uuidString)")!
        suite.set(Data(#"[{"videoId":"abc"}]"#.utf8), forKey: "savedQueue")  // a real queue, not the empty "[]" stores write at launch
        let s = AppSettings(defaults: suite)
        #expect(s.instanceURL == AppSettings.legacyInstance)
        #expect(suite.string(forKey: AppSettings.instanceKey) == AppSettings.legacyInstance)  // decided once
        pipedBase = AppSettings.defaultInstance
    }

    @Test func aStoredInstanceAlwaysWins() {
        #expect(SettingsLogic.initialInstance(stored: "https://mine.test", hasPriorData: true) == "https://mine.test")
        #expect(SettingsLogic.initialInstance(stored: "", hasPriorData: false) == AppSettings.defaultInstance)
        #expect(SettingsLogic.initialInstance(stored: nil, hasPriorData: true) == AppSettings.legacyInstance)
        #expect(SettingsLogic.initialInstance(stored: nil, hasPriorData: false) == AppSettings.defaultInstance)
    }

    @Test func priorDataMeansContentNotMerePresence() {
        let suite = UserDefaults(suiteName: "settings-\(UUID().uuidString)")!
        #expect(!SettingsLogic.hasPriorData(in: suite))
        // What the stores write on a brand-new launch, before Settings exists.
        suite.set(Data("[]".utf8), forKey: "recentItems")
        suite.set([String](), forKey: "followedChannels")
        suite.set(0, forKey: "playbackSpeed")
        #expect(!SettingsLogic.hasPriorData(in: suite))
        suite.set(1.5, forKey: "playbackSpeed")
        #expect(SettingsLogic.hasPriorData(in: suite))
    }

    @Test func aBrandNewLaunchWithEmptyStoresStartsOnTheDemoLibrary() {
        let suite = UserDefaults(suiteName: "settings-\(UUID().uuidString)")!
        suite.set(Data("[]".utf8), forKey: "savedQueue")
        suite.set(Data("[]".utf8), forKey: "recentItems")
        #expect(AppSettings(defaults: suite).instanceURL == AppSettings.defaultInstance)
        pipedBase = AppSettings.defaultInstance
    }

    @Test func hasContentByType() {
        #expect(!SettingsLogic.hasContent(nil))
        #expect(!SettingsLogic.hasContent(Data("[]".utf8)) && SettingsLogic.hasContent(Data("[{}]".utf8)))
        #expect(!SettingsLogic.hasContent([String]()) && SettingsLogic.hasContent(["x"]))
        #expect(!SettingsLogic.hasContent(0) && SettingsLogic.hasContent(2.0))
        #expect(SettingsLogic.hasContent("anything"))
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
