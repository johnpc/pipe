import Foundation

struct CommentsResponse: Codable {
    let comments: [Comment]
    let disabled: Bool?
}

/// A top-level comment on a video.
struct Comment: Codable, Identifiable, Equatable {
    let commentId: String
    let author: String
    let commentText: String
    let thumbnail: String?
    let likeCount: Int?
    let commentedTime: String?
    let verified: Bool?
    let pinned: Bool?

    var id: String { commentId }
}
