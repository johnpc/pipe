import SwiftUI

/// Feed toolbar: sort/filter menu plus links to Downloads and Saved. Extracted
/// as its own ToolbarContent so FeedView stays under the view line limit.
struct FeedToolbar: ToolbarContent {
    @Binding var sort: FeedSort
    @Binding var hideWatched: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            FeedSortMenu(sort: $sort, hideWatched: $hideWatched)
            NavigationLink(value: "trending") { Image(systemName: "flame") }
                .accessibilityIdentifier("trendingButton")
            NavigationLink(value: "downloads") { Image(systemName: "arrow.down.circle") }
                .accessibilityIdentifier("downloadsButton")
            NavigationLink(value: "saved") { Image(systemName: "bookmark") }
                .accessibilityIdentifier("savedButton")
        }
    }
}
