import Testing
import SwiftUI
@testable import pipe

struct RowMetricsTests {
    @Test func regularWidthGetsBiggerArtAndType() {
        let regular = RowMetrics.forSizeClass(.regular), compact = RowMetrics.forSizeClass(.compact)
        #expect(regular == .regular && compact == .compact)
        #expect(RowMetrics.forSizeClass(nil) == .compact)
        #expect(regular.thumbWidth > compact.thumbWidth && regular.thumbHeight > compact.thumbHeight)
        #expect(regular.rowPadding > compact.rowPadding)
        // 16:9 art in both sizes.
        #expect(abs(regular.thumbWidth / regular.thumbHeight - 16.0 / 9.0) < 0.05)
        #expect(abs(compact.thumbWidth / compact.thumbHeight - 16.0 / 9.0) < 0.1)
        #expect(RowMetrics.readableWidth > 600 && RowMetrics.readableWidth < 1000)
        #expect(regular.titleBesideArt && !compact.titleBesideArt)
        #expect(RowMetrics.headerArt(.regular) == CGSize(width: 240, height: 135))
        #expect(RowMetrics.headerArt(.compact) == CGSize(width: 100, height: 100))
    }

    @Test func sidebarMirrorsTheTabBar() {
        #expect(SidebarItem.primary.map(\.tab) == [0, 1, 2, 3])
        #expect(SidebarItem.primary.map(\.label) == ["Feed", "Search", "Recents", "Following"])
    }
}
