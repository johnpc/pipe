import Foundation

/// Queue management for PlayerState: add/remove/move/persist/restore.
extension PlayerState {
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
}
