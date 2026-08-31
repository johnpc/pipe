import Foundation
import Combine

/// Loads the now-playing video's full stream (for related videos, description,
/// and chapters) so the Full Player's tabs can show them. Comments load
/// separately in CommentsList. Keyed by video id; reloads when the track changes.
@MainActor
final class NowPlayingDetail: ObservableObject {
    @Published private(set) var state: LoadState<StreamResponse> = .loading
    private(set) var loadedVideoId: String?

    nonisolated init() {}
    nonisolated deinit {}

    /// Fetch the stream for `videoId` unless it's already loaded. A nil id (no
    /// playback) clears the state.
    func load(videoId: String?) async {
        guard let videoId else { state = .loading; loadedVideoId = nil; return }
        guard videoId != loadedVideoId else { return }
        loadedVideoId = videoId
        state = .loading
        state = LoadState.from(try? await PipedAPI.streams(videoId))
        // A failed fetch must not "claim" the id, or reopening the tab would
        // show the failure forever with no retry.
        if state.didFail { loadedVideoId = nil }
    }
}
