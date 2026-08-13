import AVFoundation
import MediaPlayer
import Combine

class PlayerState: ObservableObject {
    @Published var error: String?
    @Published var isPlaying = false
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

    var sleepTimer: Timer?
    var chaptersByVideo: [String: [Chapter]] = [:]  // chapters keyed by video id
    /// Whether playback was active when an interruption began (to decide resume).
    var wasPlayingBeforeInterruption = false
    
    var player: AVPlayer?
    /// Diagnostic logger (injectable so tests can capture emitted events).
    var log: PlaybackLog = .shared
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
    /// Video id currently loaded on the receiver, so we don't reload (and thereby
    /// abort/restart) an item that's already casting.
    var castLoadedVideoId: String?
    var currentVideoId: String?
    var timeObserver: Any?
    var endObserver: Any?
    var failedEndObserver: Any?
    var stallObserver: Any?
    var statusObserver: NSKeyValueObservation?
    var itemStatusObserver: NSKeyValueObservation?
    var sponsorObserver: Any?
    /// Sponsor segments to auto-skip for the current item.
    var sponsorSegments: [SponsorSegment] = []
    /// Piped-reported duration (seconds) of the current item, used to detect an
    /// end-of-item that fires suspiciously early (a truncated/expired stream).
    var expectedDuration: Double?
    /// How many times we've reloaded the current item to recover a premature
    /// end, so recovery is bounded and never loops forever.
    var prematureEndRetries = 0
    /// How many times we've re-resolved the current item after it failed to load
    /// at all (dead-on-arrival URL), so that recovery is likewise bounded.
    var itemFailureRetries = 0
    /// Last 30s bucket for which a progress heartbeat was logged (dedupes the
    /// 5s time-observer ticks down to ~one heartbeat per 30s).
    var lastHeartbeatBucket = -1
    /// One-shot start position (seconds) applied on the next playItem, e.g. when
    /// jumping to a chapter. Overrides the saved-resume position for that play.
    var pendingSeek: Double?

    let defaults: UserDefaults
    let queueKey = "savedQueue"
    let indexKey = "savedQueueIndex"

    let speedKey = "playbackSpeed"
    let sponsorKey = "sponsorBlockEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupAudioSession()
        setupRemoteCommands()
        observeAudioSession()
        restoreQueue()
        // Restore the user's preferred playback speed (podcast-app behavior).
        let savedSpeed = defaults.float(forKey: speedKey)
        if savedSpeed > 0 { playbackSpeed = savedSpeed }
        // Default ON; only an explicit stored `false` disables it.
        if defaults.object(forKey: sponsorKey) != nil { sponsorBlockEnabled = defaults.bool(forKey: sponsorKey) }
    }

    // Opt the deinit out of MainActor isolation to avoid a crashing async
    // executor hop on deallocation. Observers capture self weakly, so letting
    // ARC release them here is safe.
    nonisolated deinit {}
}
