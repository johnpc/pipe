import AVFoundation

/// The item lifecycle as one explicit, pure state machine — including the whole
/// load loop: it decides when a URL is resolved, when a player is built, which
/// async completion still counts (`generation`), where the next start seeks to
/// (`startAt`), and how retries, give-ups, advancing, and the background hold
/// are sequenced. `PlayerState` feeds it events and performs the effects; it
/// makes no playback decisions of its own.
///
///     idle ─load(refresh)─▶ resolving ─resolved/resolveFailed─▶ loading ─playerStarted─▶ buffering ─status(.playing)─▶ playing
///                              ▲                                                                                        │
///       ended(premature) / loadFailed(budget left) ──────── resolve(item, generation) ◀────────────────────────────────┤
///       loadFailed(budget spent) / unplayable ──▶ failed ─resume (PlayerState: load again)         pause / status(.paused) ──▶ paused
///       ended(finished | budget spent) ──▶ advance (next item loads, or stop ──▶ idle)
///
/// Leaf decisions reuse `EndOfItemPolicy` and `ItemFailurePolicy`, which stay
/// unit-tested on their own.
struct PlaybackLifecycle: Equatable {
    private(set) var phase: PlaybackPhase
    /// Video id the retry counters belong to; a different item resets them.
    private(set) var itemId: String?
    /// Bumped by every load and stop. Async work (a URL fetch, an HLS master
    /// read) carries the generation it started under; a result from an older
    /// generation is ignored, so a superseded load never installs its player.
    private(set) var generation = 0
    /// Where the next player should start, set by a premature-end recovery,
    /// a chapter jump, or a mode/language switch. Consumed by `playerStarted`.
    private(set) var startAt: Double?
    /// The current load targets a TV receiver rather than a local player.
    private(set) var casting = false
    /// Re-resolve attempts after the item failed to load at all.
    var loadFailures = 0
    /// Reloads after the item ended well short of its expected duration.
    var prematureEnds = 0

    init(phase: PlaybackPhase = .idle) {
        self.phase = phase
    }

    enum Event: Equatable {
        /// An item starts. `refresh`: fetch a fresh URL first. `casting`: a TV
        /// receiver plays it, so no local player is built.
        case load(item: QueueItem, refresh: Bool, casting: Bool)
        /// The URL fetch for `generation` came back (or didn't).
        case resolved(item: QueueItem, generation: Int)
        case resolveFailed(item: QueueItem, generation: Int)
        /// Make the next player start at this position.
        case startAt(Double)
        /// The item's stored URL cannot be used at all.
        case unplayable(title: String)
        /// A local player was built and told to play.
        case playerStarted
        /// AVPlayer reported its real `timeControlStatus`.
        case status(AVPlayer.TimeControlStatus)
        /// The TV receiver reported its playback state (while casting).
        case receiver(CastPlaybackState)
        /// The item reached `.readyToPlay`: its load succeeded.
        case ready
        case pause
        case resume
        /// The item ended (or failed to play to its end) at `reached` seconds.
        case ended(item: QueueItem?, reached: Double, expected: Double?)
        /// The item failed to load (`AVPlayerItem.status == .failed`).
        case loadFailed(item: QueueItem, reason: String, isLocal: Bool)
        /// A queue was restored at launch: an item is selected, nothing plays.
        case restored
        case stop
    }

    enum Effect: Equatable {
        case beginHold
        case releaseHold(String)
        /// Fetch fresh URLs for the item; answer with `resolved`/`resolveFailed`
        /// carrying this generation.
        case resolve(QueueItem, generation: Int)
        /// Build and start a local player for the item (its URLs are usable).
        case build(QueueItem, generation: Int)
        /// Persist freshly resolved URLs back into the queue.
        case store(QueueItem)
        /// Hand the item to the TV receiver.
        case cast(QueueItem)
        /// The item is done (or unrecoverable): move the queue along.
        case advance
        /// Tell the user; the message is also kept in `phase`.
        case surfaceError(String)
    }

    /// Whether async work started under `generation` still owns the player.
    func isCurrent(_ generation: Int) -> Bool { generation == self.generation }

    mutating func apply(_ event: Event) -> [Effect] {
        switch event {
        case let .load(item, refresh, casting):
            return load(item, refresh: refresh, casting: casting)
        case let .resolved(item, generation):
            guard isCurrent(generation) else { return [] }
            return [.store(item)] + start(item)
        case let .resolveFailed(item, generation):
            guard isCurrent(generation) else { return [] }
            return start(item)
        case let .startAt(position):
            startAt = position
            return []
        case let .unplayable(title):
            return fail("Couldn't play \(title)", holdReason: "bad url")
        case let .status(status):
            return adopt(status)
        case let .receiver(state):
            return mirror(state)
        case let .ended(item, reached, expected):
            return ended(item, reached: reached, expected: expected)
        case let .loadFailed(item, reason, isLocal):
            return loadFailed(item, reason: reason, isLocal: isLocal)
        case .playerStarted, .ready, .pause, .resume, .restored, .stop:
            return transport(event)
        }
    }

    /// A new item (or a retry of the current one) starts. Retry budgets belong
    /// to one item: a different id resets them, the same id keeps them.
    private mutating func load(_ item: QueueItem, refresh: Bool, casting: Bool) -> [Effect] {
        if itemId != item.videoId { itemId = item.videoId; loadFailures = 0; prematureEnds = 0 }
        self.casting = casting
        generation += 1
        if refresh {
            phase = .resolving
            return [.beginHold, .resolve(item, generation: generation)]
        }
        return (casting ? [] : [.beginHold]) + start(item)
    }

    /// URLs are usable: build a player, or hand off to the receiver.
    private mutating func start(_ item: QueueItem) -> [Effect] {
        if casting {
            phase = .playing
            return [.releaseHold("casting"), .cast(item)]
        }
        phase = .loading
        return [.build(item, generation: generation)]
    }

    /// Re-resolve the current item from `position` (nil: from the start).
    private mutating func retry(_ item: QueueItem, from position: Double?) -> [Effect] {
        startAt = position
        casting = false
        generation += 1
        phase = .resolving
        return [.beginHold, .resolve(item, generation: generation)]
    }

    /// The simple one-step transitions.
    private mutating func transport(_ event: Event) -> [Effect] {
        switch event {
        case .playerStarted:
            phase = .buffering
            startAt = nil
        case .ready:
            loadFailures = 0
        case .pause:
            if phase != .idle { phase = .paused }
            return [.releaseHold("pause")]
        case .resume:
            phase = .playing
        case .restored:
            phase = .paused
        case .stop:
            phase = .idle
            itemId = nil
            startAt = nil
            casting = false
            generation += 1
            loadFailures = 0
            prematureEnds = 0
            return [.releaseHold("stop")]
        default:
            break
        }
        return []
    }

    /// `timeControlStatus` is the source of truth for play/pause: an external
    /// pause (Picture in Picture, lock screen, Control Center) pauses the
    /// AVPlayer directly, so the phase follows the player rather than fighting
    /// it. Waiting only counts as buffering while we intend to play; a paused
    /// player that is also waiting stays paused.
    private mutating func adopt(_ status: AVPlayer.TimeControlStatus) -> [Effect] {
        switch status {
        case .playing:
            phase = .playing
            return [.releaseHold("playing")]
        case .paused:
            if phase == .loading || phase == .buffering || phase == .playing { phase = .paused }
            return []
        case .waitingToPlayAtSpecifiedRate:
            if phase.intendsToPlay { phase = .buffering }
            return []
        @unknown default:
            return []
        }
    }

    /// While casting, the receiver is the source of truth, like the AVPlayer
    /// locally. Idle is not mirrored: the end of an item arrives as `ended`.
    private mutating func mirror(_ state: CastPlaybackState) -> [Effect] {
        guard casting, phase != .idle, !phase.isFailed else { return [] }
        switch state {
        case .playing: phase = .playing
        case .paused: phase = .paused
        case .buffering: phase = .buffering
        case .idle: break
        }
        return []
    }

    private mutating func ended(_ item: QueueItem?, reached: Double, expected: Double?) -> [Effect] {
        switch EndOfItemPolicy.outcome(reached: reached, expected: expected, retries: prematureEnds) {
        case .finished, .giveUp:
            prematureEnds = 0
            return [.advance]
        case .recover:
            guard let item else { prematureEnds = 0; return [.advance] }
            prematureEnds += 1
            return retry(item, from: reached)
        }
    }

    private mutating func loadFailed(_ item: QueueItem, reason: String, isLocal: Bool) -> [Effect] {
        switch ItemFailurePolicy.outcome(retries: loadFailures, isLocal: isLocal) {
        case .retry:
            loadFailures += 1
            return retry(item, from: nil)
        case .giveUp:
            loadFailures = 0
            return fail(ItemFailurePolicy.failureMessage(title: item.title, reason: reason), holdReason: "gave up")
        }
    }

    private mutating func fail(_ message: String, holdReason: String) -> [Effect] {
        phase = .failed(message)
        startAt = nil
        return [.surfaceError(message), .releaseHold(holdReason)]
    }
}
