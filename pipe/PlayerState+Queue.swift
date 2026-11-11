import Foundation

/// Queue management for PlayerState: add/navigate/persist/restore. Removal
/// lives in +QueueRemove; reordering in +QueueEdit.
extension PlayerState {
    /// Append to the end of the queue.
    func addToQueue(videoId: String, url: String, audioUrl: String = "", castUrl: String = "", videoOnlyUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        enqueue(QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, audioUrl: audioUrl, castUrl: castUrl, videoOnlyUrl: videoOnlyUrl, duration: duration, uploadedDate: uploadedDate), playNext: false)
    }

    /// Insert right after the current item so it plays next.
    func playNextInQueue(videoId: String, url: String, audioUrl: String = "", castUrl: String = "", videoOnlyUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        enqueue(QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, audioUrl: audioUrl, castUrl: castUrl, videoOnlyUrl: videoOnlyUrl, duration: duration, uploadedDate: uploadedDate), playNext: true)
    }

    /// Insert (deduped by videoId), persist, and start playing if the queue was
    /// empty. Returns false when the video was already queued.
    @discardableResult
    func enqueue(_ item: QueueItem, playNext: Bool) -> Bool {
        guard !queue.contains(where: { $0.videoId == item.videoId }) else { return false }
        let insertAt = playNext && currentIndex >= 0 ? min(currentIndex + 1, queue.count) : queue.count
        queue.insert(item, at: insertAt)
        persistQueue()
        if currentIndex == -1 { playIndex(0) }
        return true
    }

    /// Store freshly resolved stream URLs on a queued (pending) item. The item
    /// now playing is left alone: its play path minted and owns its own URLs.
    func applyResolvedURLs(_ resolved: ResolvedStream) {
        guard currentVideoId != resolved.videoId,
              let idx = queue.firstIndex(where: { $0.videoId == resolved.videoId }) else { return }
        queue[idx].url = resolved.url
        queue[idx].audioUrl = resolved.audioUrl
        queue[idx].castUrl = resolved.castURL
        queue[idx].videoOnlyUrl = resolved.videoOnlyURL
        queue[idx].resolvedAt = Date()
        persistQueue()
    }

    /// Roll back an optimistic add whose stream fetch failed. Never touches the
    /// item now playing (its own error path reports that). Returns whether
    /// anything was removed.
    func removePending(videoId: String) -> Bool {
        guard currentVideoId != videoId,
              let idx = queue.firstIndex(where: { $0.videoId == videoId }) else { return false }
        removeFromQueue(at: idx)
        return true
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
    func restoreQueue() {
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
    
}
