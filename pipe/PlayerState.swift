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
    /// Minutes remaining on the sleep timer, or nil when no timer is set.
    @Published var sleepMinutesRemaining: Int?

    private var sleepTimer: Timer?
    
    var player: AVPlayer?
    var recents: RecentsStore?
    private var currentVideoId: String?
    private var timeObserver: Any?
    private var endObserver: Any?
    private var statusObserver: NSKeyValueObservation?

    private let defaults: UserDefaults
    private let queueKey = "savedQueue"
    private let indexKey = "savedQueueIndex"

    private let speedKey = "playbackSpeed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupAudioSession()
        setupRemoteCommands()
        restoreQueue()
        // Restore the user's preferred playback speed (podcast-app behavior).
        let savedSpeed = defaults.float(forKey: speedKey)
        if savedSpeed > 0 { playbackSpeed = savedSpeed }
    }

    // Opt the deinit out of MainActor isolation to avoid a crashing async
    // executor hop on deallocation. Observers capture self weakly, so letting
    // ARC release them here is safe.
    nonisolated deinit {}
    
    func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        cmd.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cmd.skipForwardCommand.preferredIntervals = [10]
        cmd.skipForwardCommand.addTarget { [weak self] _ in self?.skip(10); return .success }
        cmd.skipBackwardCommand.preferredIntervals = [10]
        cmd.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(-10); return .success }
        cmd.nextTrackCommand.addTarget { [weak self] _ in self?.playNext(); return .success }
        cmd.previousTrackCommand.addTarget { [weak self] _ in self?.playPrevious(); return .success }
    }
    
    func togglePlayPause() { if isPlaying { pause() } else { resume() } }
    func resume() { player?.play(); isPlaying = true; updateNowPlaying() }
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
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        defaults.set(speed, forKey: speedKey)
        if isPlaying { player?.rate = speed }
        updateNowPlaying()
    }
    
    func updateNowPlaying() {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle ?? "",
            MPMediaItemPropertyArtist: currentArtist ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func addToQueue(videoId: String, url: String, audioUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        // Don't add a video that's already queued.
        guard !queue.contains(where: { $0.videoId == videoId }) else { return }
        let item = QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, audioUrl: audioUrl, duration: duration, uploadedDate: uploadedDate)
        queue.append(item)
        persistQueue()
        if currentIndex == -1 { playIndex(0) }
    }
    
    func playIndex(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        currentIndex = index
        persistQueue()
        playItem(queue[index])
    }

    /// Persist the queue and current index so playback survives an app restart.
    func persistQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
            defaults.set(currentIndex, forKey: indexKey)
        }
    }

    /// Restore a previously persisted queue (paused) without auto-playing.
    private func restoreQueue() {
        guard let data = defaults.data(forKey: queueKey),
              let saved = try? JSONDecoder().decode([QueueItem].self, from: data),
              !saved.isEmpty else { return }
        queue = saved
        let idx = defaults.integer(forKey: indexKey)
        currentIndex = (idx >= 0 && idx < saved.count) ? idx : 0
        let item = queue[currentIndex]
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentVideoId = item.videoId
    }
    
    func playNext() {
        if currentIndex + 1 < queue.count { playIndex(currentIndex + 1) }
    }
    
    func playPrevious() {
        if currentIndex > 0 { playIndex(currentIndex - 1) }
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            if queue.isEmpty {
                currentIndex = -1
                stop()
            } else if currentIndex >= queue.count {
                currentIndex = queue.count - 1
            }
        }
        persistQueue()
    }
    
    func removeFromQueue(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { removeFromQueue(at: $0) }
    }
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let item = queue[sourceIndex]
        queue.remove(at: sourceIndex)
        let newIndex = destination > sourceIndex ? destination - 1 : destination
        queue.insert(item, at: newIndex)
        // Adjust currentIndex
        if sourceIndex == currentIndex {
            currentIndex = newIndex
        } else if sourceIndex < currentIndex && destination > currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destination <= currentIndex {
            currentIndex += 1
        }
        persistQueue()
    }

    func clearQueue() {
        queue.removeAll()
        currentIndex = -1
        persistQueue()
        stop()
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
    }
    
    private func playItem(_ item: QueueItem) {
        error = nil
        setupAudioSession()

        guard let url = URL(string: item.playbackURL(videoMode: videoMode)) else {
            error = "Couldn't play \(item.title)"
            return
        }

        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentTime = 0
        duration = 0
        
        if let old = timeObserver, let p = player { p.removeTimeObserver(old); timeObserver = nil }
        if let old = endObserver { NotificationCenter.default.removeObserver(old); endObserver = nil }
        statusObserver?.invalidate(); statusObserver = nil

        player = AVPlayer(url: url)

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.handleProgress(currentTime: time.seconds, itemDuration: self?.player?.currentItem?.duration.seconds)
        }

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            self?.handlePlaybackEnded()
        }

        // Recover from involuntary stalls (audio stream buffer underruns) that
        // otherwise leave playback frozen until the user manually seeks.
        statusObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.handleTimeControlStatus(p.timeControlStatus) }
        }
        
        // Resume from saved position
        let savedPos = recents?.getTimestamp(videoId: item.videoId) ?? 0
        
        // Add to recents
        recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)
        
        if savedPos > 10 {
            player?.seek(to: CMTime(seconds: savedPos, preferredTimescale: 1))
        }
        
        player?.play()
        // Apply the remembered playback speed to the new item.
        if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
        isPlaying = true
        updateNowPlaying()
    }
    
    /// Handle a periodic playback-time update: publish the current time, adopt a
    /// valid item duration, and persist progress. Extracted from the time
    /// observer closure so it is directly unit-testable.
    func handleProgress(currentTime time: Double, itemDuration: Double?) {
        self.currentTime = time
        if let d = itemDuration, d.isFinite, d > 0 { self.duration = d }
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: time)
        }
    }

    /// Handle the current item finishing: mark it complete in history, drop it
    /// from the queue, and play whatever shifts into its slot (the queue is a
    /// consumption list). Stops when the finished item was the last one.
    func handlePlaybackEnded() {
        if let vid = currentVideoId {
            recents?.updateTimestamp(videoId: vid, timestamp: 0)
        }
        let finishedIndex = currentIndex
        guard finishedIndex >= 0, finishedIndex < queue.count else { return }
        queue.remove(at: finishedIndex)
        persistQueue()
        if queue.isEmpty {
            currentIndex = -1
            stop()
        } else {
            // The next item now occupies finishedIndex (clamp for the last item).
            currentIndex = min(finishedIndex, queue.count - 1)
            playItem(queue[currentIndex])
        }
    }

    /// React to AVPlayer's timeControlStatus changing. When we intend to keep
    /// playing but the player has involuntarily stopped (a buffer-underrun
    /// stall), nudge it back to playing so audio doesn't freeze until a manual
    /// seek. Decision is delegated to the pure `StallPolicy` for testability.
    func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        if StallPolicy.shouldNudge(intendingToPlay: isPlaying, status: status) {
            player?.play()
            if playbackSpeed != 1.0 { player?.rate = playbackSpeed }
        }
    }

    func play(videoId: String, urlString: String, audioUrl: String = "", title: String?, artist: String?, thumbnail: String?, duration: Int = 0, uploadedDate: String? = nil) {
        let item = QueueItem(videoId: videoId, title: title ?? "", artist: artist ?? "", thumbnail: thumbnail ?? "", url: urlString, audioUrl: audioUrl, duration: duration, uploadedDate: uploadedDate)
        queue.insert(item, at: 0)
        playIndex(0)
    }

    /// Start a sleep timer that pauses playback after `minutes`. Passing nil or
    /// a non-positive value cancels any running timer.
    func startSleepTimer(minutes: Int?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        guard let minutes, minutes > 0 else {
            sleepMinutesRemaining = nil
            return
        }
        sleepMinutesRemaining = minutes
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSleepTimer() }
        }
    }

    /// One minute elapsed: decrement and pause when it reaches zero. Extracted so
    /// the countdown logic is unit-testable without waiting on a real Timer.
    func tickSleepTimer() {
        guard let remaining = sleepMinutesRemaining else { return }
        let next = remaining - 1
        if next <= 0 {
            sleepMinutesRemaining = nil
            sleepTimer?.invalidate()
            sleepTimer = nil
            pause()
        } else {
            sleepMinutesRemaining = next
        }
    }

    /// Toggle audio-only vs video and re-load the current item at the same
    /// position so the switch actually changes which stream is downloaded.
    func toggleVideoMode() {
        videoMode.toggle()
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let resumeAt = currentTime
        playItem(queue[currentIndex])
        if resumeAt > 1 { seek(to: resumeAt) }
    }
}
