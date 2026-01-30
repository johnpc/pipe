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
    
    var player: AVPlayer?
    var recents: RecentsStore?
    private var currentVideoId: String?
    private var timeObserver: Any?
    private var endObserver: Any?
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
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
    
    func addToQueue(videoId: String, url: String, title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        let item = QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, duration: duration, uploadedDate: uploadedDate)
        queue.append(item)
        if currentIndex == -1 { playIndex(0) }
    }
    
    func playIndex(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        currentIndex = index
        playItem(queue[index])
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
    }
    
    func clearQueue() {
        queue.removeAll()
        currentIndex = -1
        stop()
    }
    
    func stop() {
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
        
        guard let url = URL(string: item.url) else { error = "Invalid URL"; return }
        
        currentVideoId = item.videoId
        currentTitle = item.title
        currentArtist = item.artist
        currentThumbnail = item.thumbnail
        currentTime = 0
        duration = 0
        
        if let old = timeObserver, let p = player { p.removeTimeObserver(old); timeObserver = nil }
        if let old = endObserver { NotificationCenter.default.removeObserver(old); endObserver = nil }
        
        player = AVPlayer(url: url)
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
            // Save progress to recents
            if let vid = self.currentVideoId {
                self.recents?.updateTimestamp(videoId: vid, timestamp: time.seconds)
            }
        }
        
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            // Mark as complete (timestamp 0)
            if let vid = self?.currentVideoId {
                self?.recents?.updateTimestamp(videoId: vid, timestamp: 0)
            }
            self?.playNext()
        }
        
        // Resume from saved position
        let savedPos = recents?.getTimestamp(videoId: item.videoId) ?? 0
        
        // Add to recents
        recents?.add(videoId: item.videoId, title: item.title, artist: item.artist, thumbnail: item.thumbnail, timestamp: savedPos, duration: item.duration, uploadedDate: item.uploadedDate)
        
        if savedPos > 10 {
            player?.seek(to: CMTime(seconds: savedPos, preferredTimescale: 1))
        }
        
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }
    
    func play(videoId: String, urlString: String, title: String?, artist: String?, thumbnail: String?, duration: Int = 0, uploadedDate: String? = nil) {
        let item = QueueItem(videoId: videoId, title: title ?? "", artist: artist ?? "", thumbnail: thumbnail ?? "", url: urlString, duration: duration, uploadedDate: uploadedDate)
        queue.insert(item, at: 0)
        playIndex(0)
    }
}
