import Foundation

/// Runs the item state machine: feed an event to `PlaybackLifecycle`, then
/// carry out the effects it asked for. This is the only place the phase
/// changes, so `isPlaying`/`isBuffering`, the retry budgets, the start
/// position, and the load generation can never disagree with each other.
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
        case let .resolve(item, generation):
            resolveAndPlay(item, generation: generation)
        case let .build(item, generation):
            buildPlayer(for: item, generation: generation)
        case let .store(item):
            updateQueueItem(item)
        case let .cast(item):
            castItem(item)
        case .advance:
            advanceAfterFinish()
        case let .surfaceError(message):
            error = message
        }
    }

    /// Put the machine in `phase` directly, discarding its bookkeeping. For
    /// tests that need a starting state; production code goes through `apply`.
    func setPhase(_ phase: PlaybackPhase) {
        lifecycle = PlaybackLifecycle(phase: phase)
    }
}
