import Foundation
import Combine

/// Loads the now-playing video's full stream (for related videos, description,
/// and chapters) so the Full Player's tabs can show them. Comments load
/// separately in CommentsList. Keyed by video id; reloads when the track changes.
@MainActor
final class NowPlayingDetail: ObservableObject {
    @Published private(set) var state: LoadState<StreamResponse> = .loading
    private(set) var loadedVideoId: String?
    private let fetch: @Sendable (String) async throws -> StreamResponse

    /// `fetch` is injectable so cancellation and failure are unit-testable.
    nonisolated init(fetch: @escaping @Sendable (String) async throws -> StreamResponse = { try await PipedAPI.streams($0) }) {
        self.fetch = fetch
    }
    nonisolated deinit {}

    /// Fetch the stream for `videoId` unless it's already loaded. A nil id (no
    /// playback) clears the state.
    func load(videoId: String?) async {
        guard let videoId else { state = .loading; loadedVideoId = nil; return }
        guard videoId != loadedVideoId else { return }
        loadedVideoId = videoId
        state = .loading
        let result = try? await fetch(videoId)
        // Cancelled (the view's `.task` was torn down mid-fetch): this is not a
        // failure — stay "loading" and forget the id so the next appearance
        // fetches again instead of showing "Nothing here" with no way back.
        if Task.isCancelled { loadedVideoId = nil; return }
        state = LoadState.from(result)
        // A failed fetch must not "claim" the id, or reopening the tab would
        // show the failure forever with no retry.
        if state.didFail { loadedVideoId = nil }
    }
}
