import AVFoundation

/// The item lifecycle as one explicit, pure state machine.
///
/// `PlayerState` feeds it events and performs the effects it returns, so every
/// decision about retrying a dead URL, recovering a premature end, advancing
/// the queue, holding the background task, and what the UI shows is readable
/// and testable in one place instead of being spread over observers. Leaf
/// decisions reuse the existing policies (`EndOfItemPolicy`,
/// `ItemFailurePolicy`), which stay unit-tested on their own.
///
/// Phase diagram (happy path left to right, recovery loops back):
///
///     idle ─load(refresh)─▶ resolving ─load─▶ loading ─playerStarted─▶ buffering ─status(.playing)─▶ playing
///                                                                                                     │
///       ended(premature) / loadFailed(retry) ──▶ resolving (retryWithFreshURL) ◀───────────────────────┤
///       loadFailed(giveUp) ──▶ failed ─resume─▶ (load again)              pause / status(.paused) ──▶ paused
///       ended(finished|giveUp) ──▶ advance (next item loads, or stop ──▶ idle)
struct PlaybackLifecycle: Equatable {
    private(set) var phase: PlaybackPhase
    /// Video id the retry counters belong to; a different item resets them.
    private(set) var itemId: String?
    /// Re-resolve attempts after the item failed to load at all.
    var loadFailures = 0
    /// Reloads after the item ended well short of its expected duration.
    var prematureEnds = 0

    init(phase: PlaybackPhase = .idle) {
        self.phase = phase
    }

    enum Event: Equatable {
        /// An item starts loading. `refresh`: its URL is fetched first.
        /// `casting`: a TV receiver plays it, so there is no local player.
        case load(videoId: String, refresh: Bool, casting: Bool)
        /// The item's stored URL cannot be used at all.
        case unplayable(title: String)
        /// A local player was built and told to play.
        case playerStarted
        /// AVPlayer reported its real `timeControlStatus`.
        case status(AVPlayer.TimeControlStatus)
        /// The item reached `.readyToPlay`: its load succeeded.
        case ready
        case pause
        case resume
        /// The item ended (or failed to play to its end) at `reached` seconds.
        case ended(reached: Double, expected: Double?)
        /// The item failed to load (`AVPlayerItem.status == .failed`).
        case loadFailed(title: String, reason: String, isLocal: Bool)
        /// A queue was restored at launch: an item is selected, nothing plays.
        case restored
        case stop
    }

    enum Effect: Equatable {
        case beginHold
        case releaseHold(String)
        /// Fetch a fresh URL for the current item and load it again, resuming
        /// at `seekTo` when non-nil.
        case retryWithFreshURL(seekTo: Double?)
        /// The item is done (or unrecoverable): move the queue along.
        case advance
        /// Tell the user; the message is also kept in `phase`.
        case surfaceError(String)
    }

    mutating func apply(_ event: Event) -> [Effect] {
        switch event {
        case let .load(videoId, refresh, casting):
            return load(videoId, refresh: refresh, casting: casting)
        case let .unplayable(title):
            return fail("Couldn't play \(title)", holdReason: "bad url")
        case let .status(status):
            return adopt(status)
        case let .ended(reached, expected):
            return ended(reached: reached, expected: expected)
        case let .loadFailed(title, reason, isLocal):
            return loadFailed(title: title, reason: reason, isLocal: isLocal)
        case .playerStarted, .ready, .pause, .resume, .restored, .stop:
            return transport(event)
        }
    }

    /// A new item (or a retry of the current one) starts loading. Retry budgets
    /// belong to one item: a different id resets them, the same id keeps them.
    private mutating func load(_ videoId: String, refresh: Bool, casting: Bool) -> [Effect] {
        if itemId != videoId { itemId = videoId; loadFailures = 0; prematureEnds = 0 }
        if casting { phase = .playing; return [.releaseHold("casting")] }
        phase = refresh ? .resolving : .loading
        return [.beginHold]
    }

    /// The simple one-step transitions.
    private mutating func transport(_ event: Event) -> [Effect] {
        switch event {
        case .playerStarted:
            phase = .buffering
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

    private mutating func ended(reached: Double, expected: Double?) -> [Effect] {
        switch EndOfItemPolicy.outcome(reached: reached, expected: expected, retries: prematureEnds) {
        case .finished, .giveUp:
            prematureEnds = 0
            return [.advance]
        case .recover:
            prematureEnds += 1
            phase = .resolving
            return [.retryWithFreshURL(seekTo: reached)]
        }
    }

    private mutating func loadFailed(title: String, reason: String, isLocal: Bool) -> [Effect] {
        switch ItemFailurePolicy.outcome(retries: loadFailures, isLocal: isLocal) {
        case .retry:
            loadFailures += 1
            phase = .resolving
            return [.retryWithFreshURL(seekTo: nil)]
        case .giveUp:
            loadFailures = 0
            return fail(ItemFailurePolicy.failureMessage(title: title, reason: reason), holdReason: "gave up")
        }
    }

    private mutating func fail(_ message: String, holdReason: String) -> [Effect] {
        phase = .failed(message)
        return [.surfaceError(message), .releaseHold(holdReason)]
    }
}
