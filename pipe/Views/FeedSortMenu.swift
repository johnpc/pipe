import SwiftUI

/// Feed sort + filter toolbar menu, extracted so FeedView stays declarative and
/// under the view line limit.
struct FeedSortMenu: View {
    @Binding var sort: FeedSort
    @Binding var hideWatched: Bool

    var body: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(FeedSort.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Toggle("Hide Watched", isOn: $hideWatched)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("feedMenu")
    }
}
