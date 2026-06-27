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
    var recents: RecentsStore?
    var downloads: DownloadStore?
    var currentVideoId: String?
    var timeObserver: Any?
    var endObserver: Any?
    var statusObserver: NSKeyValueObservation?
    /// One-shot start position (seconds) applied on the next playItem, e.g. when
    /// jumping to a chapter. Overrides the saved-resume position for that play.
    var pendingSeek: Double?

    let defaults: UserDefaults
    let queueKey = "savedQueue"
    let indexKey = "savedQueueIndex"

    let speedKey = "playbackSpeed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupAudioSession()
        setupRemoteCommands()
        observeAudioSession()
        restoreQueue()
        // Restore the user's preferred playback speed (podcast-app behavior).
        let savedSpeed = defaults.float(forKey: speedKey)
        if savedSpeed > 0 { playbackSpeed = savedSpeed }
    }

    // Opt the deinit out of MainActor isolation to avoid a crashing async
    // executor hop on deallocation. Observers capture self weakly, so letting
    // ARC release them here is safe.
    nonisolated deinit {}
    
    func togglePlayPause() { if isPlaying { pause() } else { resume() } }

    func resume() {
        // After a cold launch the queue is restored but no AVPlayer exists yet;
        // start the current item instead of a silent no-op.
        if player == nil, currentIndex >= 0, currentIndex < queue.count {
            playItem(queue[currentIndex])
            return
        }
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() { player?.pause(); isPlaying = false; updateNowPlaying() }
    
    func skip(_ seconds: Double) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        currentTime = time
        updateNowPlaying()
    }

    func stop() {
        statusObserver?.invalidate(); statusObserver = nil
        player?.pause()
        isPlaying = false
        currentTitle = nil
        currentArtist = nil
        currentThumbnail = nil
        currentTime = 0
        duration = 0
        currentChapterTitle = nil
    }
}
