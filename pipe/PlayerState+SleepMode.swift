import Foundation

/// Sleep timer + audio/video mode toggle for PlayerState.
extension PlayerState {
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
    /// The position rides through `pendingSeek` (not a post-hoc `seek`) because
    /// a stale item takes the async refresh path, where an immediate seek would
    /// land on the OLD player and the position would be lost when the fresh
    /// stream finally loads at the saved-resume offset instead.
    func toggleVideoMode() {
        videoMode.toggle()
        defaults.set(videoMode, forKey: videoModeKey)
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        if currentTime > 1 { pendingSeek = currentTime }
        playItem(queue[currentIndex])
    }
}
