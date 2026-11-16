import Foundation
@testable import pipe

/// Canned stream resolver: answers with `result` (a copy of the item with the
/// given fresh URL, or nil for a failure) and records what it was asked for.
final class MockStreamResolver: StreamResolving, @unchecked Sendable {
    var freshURL: String?
    private(set) var requested: [String] = []
    private let lock = NSLock()

    init(freshURL: String? = "https://fresh.example/a.m4a") {
        self.freshURL = freshURL
    }

    func fresh(_ item: QueueItem) async -> QueueItem? {
        lock.lock(); requested.append(item.videoId); lock.unlock()
        guard let freshURL else { return nil }
        var copy = item
        copy.audioUrl = freshURL
        copy.url = freshURL
        copy.resolvedAt = Date()
        return copy
    }
}
