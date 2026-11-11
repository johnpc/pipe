import Foundation

/// Instant queueing. A list row already knows the title, thumbnail, and
/// duration, so "Add to queue" inserts the item right away and the stream URLs
/// resolve in the background. (Before this, the add blocked on a full stream
/// fetch — seconds on a slow instance — behind an "Adding..." spinner.)
extension Playback {
    /// Entry point for list rows. `.queue` / `.playNext` insert now and resolve
    /// later — except when nothing is playing: then the add *is* a play (the
    /// first item starts at once) and there's nothing to show until a URL
    /// exists, so it takes the fetch-first path, same as `.play`.
    @MainActor
    static func perform(_ item: QueueItem, action: Action, player: PlayerState, toast: ToastManaging? = nil) {
        guard action != .play, player.currentIndex >= 0 else {
            Task { await run(videoId: item.videoId, action: action, player: player, toast: toast) }
            return
        }
        guard enqueueNow(item, action: action, player: player, toast: toast) else { return }
        Task { await resolvePending(item.videoId, action: action, player: player, toast: toast) }
    }

    /// Insert immediately and confirm with the success toast. Returns whether a
    /// background resolution is still needed: false when the video was already
    /// queued, or when it started playing on the spot (an empty queue plays its
    /// first item, and that play path resolves the URL itself).
    @MainActor @discardableResult
    static func enqueueNow(_ item: QueueItem, action: Action, player: PlayerState, toast: ToastManaging? = nil) -> Bool {
        let inserted = player.enqueue(item, playNext: action == .playNext)
        (toast ?? ToastManager.shared).showSuccess(successMessage(for: action))
        return inserted && player.currentVideoId != item.videoId
    }

    /// Fill in a pending item's stream URLs. If the fetch fails, the optimistic
    /// add is rolled back: the item is removed and the toast names the reason,
    /// exactly as a blocking add used to fail (and logged the same way). An
    /// item that started playing meanwhile is left alone — its own play path
    /// reports that failure.
    @MainActor
    static func resolvePending(_ videoId: String, action: Action = .queue, player: PlayerState, toast: ToastManaging? = nil) async {
        do {
            let stream = try await PipedAPI.streams(videoId)
            let resolved = resolve(stream, videoId: videoId)
            player.registerChapters(resolved.chapters, for: videoId)
            player.applyResolvedURLs(resolved)
        } catch {
            player.log.event("playbackError", errorEventName(for: action),
                             fields: ["videoId": videoId, "reason": errorReason(error),
                                      "error": error.localizedDescription])
            guard player.removePending(videoId: videoId) else { return }
            (toast ?? ToastManager.shared).showError(errorMessage(for: action, error: error))
        }
    }
}
