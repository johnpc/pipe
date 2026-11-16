import Foundation

/// Where playback is in the current item's life, as one value. This replaces
/// the `isPlaying` + `isBuffering` + `player == nil` + `error` combination that
/// views, tests, and log readers used to infer it from. `PlaybackLifecycle`
/// owns the transitions; `PlayerState` publishes the result.
enum PlaybackPhase: Equatable {
    /// Nothing selected: empty queue, or stopped. The mini player is hidden.
    case idle
    /// Fetching a fresh stream URL for the item before it can load.
    case resolving
    /// A player (or playlist) is being built; nothing is audible yet.
    case loading
    /// The player intends to play but is waiting on data (initial or re-buffer).
    case buffering
    case playing
    /// Not playing by choice: user pause, an external pause, or restored at launch.
    case paused
    /// Gave up on the item; the payload is what the user was told.
    case failed(String)

    /// The player intends to produce audio (drives the pause glyph).
    var intendsToPlay: Bool {
        switch self {
        case .resolving, .loading, .buffering, .playing: return true
        case .idle, .paused, .failed: return false
        }
    }

    /// Intends to play but nothing is audible yet (drives the spinner).
    var isWaiting: Bool {
        switch self {
        case .resolving, .loading, .buffering: return true
        case .idle, .playing, .paused, .failed: return false
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Secondary line for the mini player while the state is worth explaining
    /// to the user; nil when the artist line should show instead.
    var statusText: String? {
        switch self {
        case .resolving, .loading: return "Loading…"
        case .buffering: return "Buffering…"
        case .failed: return "Couldn't play. Tap play to retry."
        case .idle, .playing, .paused: return nil
        }
    }

    /// What the mini player's second line shows: the status while it matters,
    /// otherwise the artist.
    func subtitle(artist: String?) -> String {
        statusText ?? artist ?? ""
    }

    /// Short label for accessibility values, UI tests, and diagnostics.
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .resolving: return "Resolving"
        case .loading: return "Loading"
        case .buffering: return "Buffering"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .failed: return "Failed"
        }
    }
}
