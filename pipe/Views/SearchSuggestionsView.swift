import SwiftUI

/// Empty-state screen for Search: inline field + popular-channel suggestions.
struct SearchSuggestionsView: View {
    @Binding var query: String
    let suggestions: [String]
    var history: [String] = []
    let onSearch: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
                Text("Search Videos")
                    .font(.title2)

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent").font(.headline)
                        ForEach(history, id: \.self) { term in
                            Button { onSearch(term) } label: {
                                Label(term, systemImage: "clock.arrow.circlepath")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                // Inline search field for better iPad compatibility
                HStack {
                    TextField("Search...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onSearch(query) }
                    Button { onSearch(query) } label: {
                        Image(systemName: "magnifyingglass")
                            .padding(8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(!SearchLogic.isSubmittable(query))
                }
                .padding(.horizontal, 40)

                Text("Or try one of these popular channels")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button { onSearch(suggestion) } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
