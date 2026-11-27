import SwiftUI

/// Segmented All / Videos / Channels / Playlists control under the search field.
struct SearchFilterBar: View {
    @Binding var filter: SearchFilter

    var body: some View {
        Picker("Result type", selection: $filter) {
            ForEach(SearchFilter.allCases) { f in
                Text(f.label).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityIdentifier("searchFilter")
    }
}
