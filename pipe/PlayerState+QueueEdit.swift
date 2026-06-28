import Foundation

/// Queue reordering and clearing for PlayerState.
extension PlayerState {
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
