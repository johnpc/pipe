import SwiftUI

/// A single comment row: author (with verified/pinned badges), likes, and text.
struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(comment.author).font(.caption).bold()
                if comment.verified == true {
                    Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.secondary)
                }
                if comment.pinned == true {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let likes = comment.likeCount, likes > 0 {
                    Label("\(likes)", systemImage: "hand.thumbsup").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(HTMLText.plainText(comment.commentText)).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
