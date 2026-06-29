import SwiftUI

/// Comments for a video, presented as a sheet from DetailView. Wraps the shared
/// CommentsList in navigation chrome.
struct CommentsView: View {
    let videoId: String

    var body: some View {
        NavigationStack {
            CommentsList(videoId: videoId)
                .navigationTitle("Comments")
        }
    }
}
