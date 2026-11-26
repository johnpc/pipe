import SwiftUI

// The only views that observe `PlaybackClock`, so the once-a-second position
// update re-renders these few leaves and nothing else (not the screens behind
// the player, and not the player's own controls).

/// The thin progress line across the top of the mini player.
struct ClockProgressBar: View {
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        ProgressView(value: min(clock.currentTime, max(clock.duration, 1)), total: max(clock.duration, 1))
            .tint(.accentColor)
            .scaleEffect(x: 1, y: 0.5, anchor: .center)
    }
}

/// "12:03 / 45:10", for the wide mini player.
struct ClockTimeLabel: View {
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        Text("\(formatTime(clock.currentTime)) / \(formatTime(clock.duration))")
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }
}

/// The full player's seek slider with elapsed and total time under it.
struct PlayerScrubber: View {
    @ObservedObject var clock: PlaybackClock
    let onSeek: (Double) -> Void

    var body: some View {
        Slider(value: Binding(get: { clock.currentTime }, set: onSeek), in: 0...max(clock.duration, 1))
            .tint(.accentColor)
        HStack {
            Text(formatTime(clock.currentTime)).font(.caption).accessibilityIdentifier("elapsedTime")
            Spacer()
            Text(formatTime(clock.duration)).font(.caption).accessibilityIdentifier("totalTime")
        }.foregroundStyle(.secondary)
    }
}
