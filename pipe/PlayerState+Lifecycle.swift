import Foundation

/// Runs the item state machine: feed an event to `PlaybackLifecycle`, publish
/// the resulting phase, and carry out the effects it asked for. This is the
/// only place phase changes, so `isPlaying`/`isBuffering` can never disagree
/// with each other or with the retry bookkeeping.
extension PlayerState {
    func apply(_ event: PlaybackLifecycle.Event) {
        let effects = lifecycle.apply(event)
        effects.forEach(perform)
    }

    private func perform(_ effect: PlaybackLifecycle.Effect) {
        switch effect {
        case .beginHold:
            holdForTransition()
        case let .releaseHold(reason):
            releaseTransitionHold(reason)
        case let .retryWithFreshURL(seekTo):
            guard currentIndex >= 0, currentIndex < queue.count else { return }
            if let seekTo { pendingSeek = seekTo }
            playItem(queue[currentIndex], refresh: .force)
        case .advance:
            advanceAfterFinish()
        case let .surfaceError(message):
            error = message
        }
    }

    /// Put the machine in `phase` directly, discarding retry bookkeeping. For
    /// tests that need a starting state; production code goes through `apply`.
    func setPhase(_ phase: PlaybackPhase) {
        lifecycle = PlaybackLifecycle(phase: phase)
    }
}
