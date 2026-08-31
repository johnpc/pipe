import Foundation

/// Queue removal for PlayerState — split from +Queue because removing the
/// now-playing item has real transport consequences (stop, advance, or retire
/// a ghost player), not just index bookkeeping.
extension PlayerState {
    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        let removedCurrent = index == currentIndex
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if removedCurrent {
            if queue.isEmpty {
                currentIndex = -1
                stop()
            } else {
                removedCurrentItem()
            }
        }
        persistQueue()
    }

    /// The removed item was the one playing: don't leave its audio running as a
    /// ghost — move to the item now occupying its slot (or the new last item)
    /// and play it if we were playing.
    private func removedCurrentItem() {
        currentIndex = min(currentIndex, queue.count - 1)
        if isPlaying {
            playItem(queue[currentIndex])
        } else {
            // Paused: retire the removed item's player without starting the
            // next one, and surface the next item's metadata.
            teardownPlaybackObservers()
            releaseCurrentPlayer()
            let item = queue[currentIndex]
            currentTitle = item.title
            currentArtist = item.artist
            currentThumbnail = item.thumbnail
            currentVideoId = item.videoId
            currentTime = 0
            duration = item.duration > 0 ? Double(item.duration) : 0
            updateNowPlaying()
        }
    }

    func removeFromQueue(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { removeFromQueue(at: $0) }
    }
}
