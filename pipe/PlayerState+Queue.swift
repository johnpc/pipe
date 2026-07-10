import Foundation

/// Queue management for PlayerState: add/remove/move/persist/restore.
extension PlayerState {
    /// Append to the end of the queue.
    func addToQueue(videoId: String, url: String, audioUrl: String = "", castUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        enqueue(QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, audioUrl: audioUrl, castUrl: castUrl, duration: duration, uploadedDate: uploadedDate), playNext: false)
    }

    /// Insert right after the current item so it plays next.
    func playNextInQueue(videoId: String, url: String, audioUrl: String = "", castUrl: String = "", title: String, artist: String, thumbnail: String, duration: Int = 0, uploadedDate: String? = nil) {
        enqueue(QueueItem(videoId: videoId, title: title, artist: artist, thumbnail: thumbnail, url: url, audioUrl: audioUrl, castUrl: castUrl, duration: duration, uploadedDate: uploadedDate), playNext: true)
    }

    private func enqueue(_ item: QueueItem, playNext: Bool) {
        guard !queue.contains(where: { $0.videoId == item.videoId }) else { return }
        let insertAt = playNext && currentIndex >= 0 ? min(currentIndex + 1, queue.count) : queue.count
        queue.insert(item, at: insertAt)
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
}
