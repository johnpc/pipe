import Testing
@testable import pipe

struct OfflineLogicTests {

    // MARK: - Online routing is the plain tab mapping

    @Test func onlineRoutesEachTabToItsScreen() {
        #expect(OfflineLogic.screen(forTab: 0, offline: false) == .feed)
        #expect(OfflineLogic.screen(forTab: 1, offline: false) == .search)
        #expect(OfflineLogic.screen(forTab: 2, offline: false) == .recents)
        #expect(OfflineLogic.screen(forTab: 3, offline: false) == .following)
    }

    // MARK: - Offline substitutes network tabs, keeps local ones

    @Test func offlineSwapsFeedForDownloads() {
        #expect(OfflineLogic.screen(forTab: 0, offline: true) == .downloads)
    }

    @Test func offlineSwapsSearchForPlaceholder() {
        #expect(OfflineLogic.screen(forTab: 1, offline: true) == .offlinePlaceholder)
    }

    @Test func offlineLeavesLocalTabsAlone() {
        // Recents + Following read persisted state, so they still work offline.
        #expect(OfflineLogic.screen(forTab: 2, offline: true) == .recents)
        #expect(OfflineLogic.screen(forTab: 3, offline: true) == .following)
    }

    @Test func unknownTabFallsBackToHome() {
        #expect(OfflineLogic.screen(forTab: 9, offline: false) == .feed)
        #expect(OfflineLogic.screen(forTab: 9, offline: true) == .downloads)
        #expect(OfflineLogic.homeTab == 0)
    }
}
