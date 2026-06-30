import SwiftUI

/// The comments list body (no navigation chrome), so it can be embedded both in
/// the CommentsView sheet and the Full Player's Comments tab. Loads on appear,
/// keyed by videoId.
struct CommentsList: View {
    let videoId: String
    /// Seek the live player when a comment's timestamp link is tapped. Nil in
    /// contexts without a relevant playing video (links then open normally).
    var onSeek: ((Double) -> Void)? = nil
    @State private var state: LoadState<[Comment]> = .loading
    @State private var disabled = false

    var body: some View {
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
        .environment(\.openURL, OpenURLAction { url in
            guard let secs = DescriptionLinks.seekSeconds(from: url), let onSeek else { return .systemAction }
            onSeek(secs)
            return .handled
        })
        .task(id: videoId) { await load() }
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
