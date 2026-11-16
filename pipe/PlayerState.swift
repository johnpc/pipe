import AVFoundation
import MediaPlayer
import Combine

class PlayerState: ObservableObject {
    /// One-shot error channel: ContentView turns a non-nil value into a toast
    /// and clears it. The lasting state lives in `phase` (`.failed`).
    @Published var error: String?
    /// The item state machine (see `PlaybackLifecycle`). Mutated only through
    /// `apply(_:)` so phase and retry bookkeeping always agree.
    @Published var lifecycle = PlaybackLifecycle()
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentTitle: String?
    @Published var currentArtist: String?
    @Published var currentThumbnail: String?
    @Published var playbackSpeed: Float = 1.0
    @Published var queue: [QueueItem] = []
    @Published var currentIndex: Int = -1
    @Published var videoMode = false
    /// Auto-skip SponsorBlock segments; on by default, persisted across launches.
    @Published var sponsorBlockEnabled = true { didSet { defaults.set(sponsorBlockEnabled, forKey: sponsorKey) } }
    @Published var sleepMinutesRemaining: Int?  // nil = no timer
    /// Stop at the end of the current item ("sleep at end of episode").
    @Published var stopAfterCurrentEpisode = false
    /// Active chapter title at the current time; drives the now-playing label.
    @Published var currentChapterTitle: String?

    /// Where the current item is in its life; the single source of truth the
    /// derived flags below read from.
    var phase: PlaybackPhase { lifecycle.phase }
    /// The player intends to produce audio (pause glyph shown).
    var isPlaying: Bool { phase.intendsToPlay }
    /// Intends to play but nothing is audible yet (spinner shown) — initial
    /// resolve/load/buffer or a mid-play rebuffer.
    var isBuffering: Bool { phase.isWaiting }

    var sleepTimer: Timer?
    var chaptersByVideo: [String: [Chapter]] = [:]  // chapters keyed by video id
    /// Whether playback was active when an interruption began (to decide resume).
    var wasPlayingBeforeInterruption = false
    
    var player: AVPlayer?
    /// Serves the playlists of the composed (video mode) item now playing.
    var composedLoader: HLSPlaylistLoader?
    /// Diagnostic logger (injectable so tests can capture emitted events).
    var log: PlaybackLog = .shared
    /// Gapless hand-off state: background hold + next-item prefetch (injectable).
    var transition = ItemTransition()
    /// Whether the opt-in remote diagnostics sink has been attached this launch.
    var remoteDiagnosticsAttached = false
    /// Whether the one-shot session-start event has been logged this launch.
    var sessionStartLogged = false
    var recents: RecentsStore?
    var downloads: DownloadStore?
    /// Cast receiver, when the user has connected to a TV. While casting,
    /// transport drives the receiver instead of the local `AVPlayer`.
    var cast: CastStore?
    /// Mirrors the receiver's playback time back onto `currentTime` while casting.
    var castTimeCancellable: AnyCancellable?
    /// Watches the receiver connection so the current item hands off on connect.
    var castConnectionCancellable: AnyCancellable?
    /// Mirrors the receiver's play/pause/buffering onto the phase while casting.
    var castPlaybackCancellable: AnyCancellable?
    /// Video id currently loaded on the receiver, so we don't reload (and thereby
    /// abort/restart) an item that's already casting.
    var castLoadedVideoId: String?
    var currentVideoId: String?
    /// Handles for the observers on the live player (see +Observers).
    var observers = PlaybackObserverHandles()
    /// Sponsor segments to auto-skip for the current item.
    var sponsorSegments: [SponsorSegment] = []
    /// Piped-reported duration (seconds) of the current item, used to detect an
    /// end-of-item that fires suspiciously early (a truncated/expired stream).
    var expectedDuration: Double?
    /// Reloads of the current item to recover a premature end (bounded by
    /// `EndOfItemPolicy`). Lives in the lifecycle; exposed for tests/logs.
    var prematureEndRetries: Int {
        get { lifecycle.prematureEnds }
        set { lifecycle.prematureEnds = newValue }
    }
    /// Re-resolves of the current item after it failed to load at all (bounded
    /// by `ItemFailurePolicy`). Lives in the lifecycle; exposed for tests/logs.
    var itemFailureRetries: Int {
        get { lifecycle.loadFailures }
        set { lifecycle.loadFailures = newValue }
    }
    /// Mints fresh stream URLs (injectable; see `StreamResolver`).
    var resolver: StreamResolving = PipedStreamResolver()
    /// Last 30s bucket for which a progress heartbeat was logged (dedupes the
    /// 5s time-observer ticks down to ~one heartbeat per 30s).
    var lastHeartbeatBucket = -1
    /// Where the next player starts (chapter jump, mode/language switch, or a
    /// premature-end recovery). Owned by the lifecycle; set via `.startAt`.
    var pendingSeek: Double? { lifecycle.startAt }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupAudioSession()
        setupRemoteCommands()
        observeAudioSession()
        restoreQueue()
        restorePreferences()
    }

    // Opt the deinit out of MainActor isolation to avoid a crashing async
    // executor hop on deallocation. Observers capture self weakly, so letting
    // ARC release them here is safe.
    nonisolated deinit {}
}
