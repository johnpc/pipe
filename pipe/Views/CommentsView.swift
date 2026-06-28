import SwiftUI

/// Comments for a video, loaded on appear. Presented as a sheet from DetailView.
struct CommentsView: View {
    let videoId: String
    @State private var state: LoadState<[Comment]> = .loading
    @State private var disabled = false

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading: ProgressView()
                case .failed: RetryView { Task { await load() } }
                case .loaded(let comments):
                    if disabled || comments.isEmpty {
                        ContentUnavailableView("No Comments", systemImage: "text.bubble")
                    } else {
                        List(comments) { CommentRow(comment: $0) }.listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Comments")
            .task { await load() }
        }
    }

    private func load() async {
        state = .loading
        if let response = try? await PipedAPI.comments(videoId) {
            disabled = response.disabled ?? false
            state = .loaded(response.comments)
        } else {
            state = .failed
        }
    }
}
