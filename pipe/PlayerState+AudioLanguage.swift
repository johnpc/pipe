import Foundation

/// Per-item audio language: switch a dubbed video to another of its tracks
/// from the player without changing the Settings default.
extension PlayerState {
    /// Audio URL of the item now playing, for showing which track is active.
    var currentAudioURL: String? {
        guard currentIndex >= 0, currentIndex < queue.count else { return nil }
        return queue[currentIndex].audioUrl
    }

    /// The language the current item should play in: its own pick, else the
    /// Settings preference.
    var currentAudioLanguageChoice: String {
        guard currentIndex >= 0, currentIndex < queue.count else { return pipedAudioLanguage }
        return queue[currentIndex].audioLanguage ?? pipedAudioLanguage
    }

    /// Switch the current item to its `language` track and resume at the same
    /// position. The choice is stored on the item so a later URL refresh
    /// re-resolves the same language. No-op when the video lacks audio streams.
    func selectAudioLanguage(_ language: String, from streams: [AudioStream]) {
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let url = AudioLanguageLogic.bestURL(from: streams, preferred: language)
        guard !url.isEmpty else { return }
        var item = queue[currentIndex]
        item.audioLanguage = language
        item.audioUrl = url
        queue[currentIndex] = item
        persistQueue()
        log.event("play", "audio language", fields: ["videoId": item.videoId, "language": language])
        // The receiver plays the muxed stream, which has one fixed track; the
        // choice still applies once casting ends. Video mode reloads too: it
        // pairs the video-only track with this audio track (see +Composed).
        guard !isCasting else { return }
        if currentTime > 1 { pendingSeek = currentTime }
        playItem(item, skipRefresh: true)
    }
}
