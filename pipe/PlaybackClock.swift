import Combine
import Foundation

/// The playback position, published on its own.
///
/// It changes every second while something plays. On `PlayerState` it made
/// every screen observing the player (the feed, search, history...) re-render
/// each second, in the background too, enough that iOS killed the app for CPU
/// on 2026-11-26. Only the views that show the time (the mini player's bar,
/// the full player's scrubber) observe this; `PlayerState.currentTime` and
/// `.duration` read and write through to it so the logic is unchanged.
final class PlaybackClock: ObservableObject {
    @Published var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    /// Publishes only on a real change: the time observer re-reports the same
    /// item duration every tick.
    func setDuration(_ value: Double) {
        if duration != value { duration = value }
    }
}
