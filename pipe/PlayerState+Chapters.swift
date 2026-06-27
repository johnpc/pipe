import Foundation

/// Chapter tracking for the now-playing label.
extension PlayerState {
    /// Record the chapters for a video so the now-playing label can show the
    /// active one. Called when a stream is resolved for playback.
    func registerChapters(_ chapters: [Chapter], for videoId: String) {
        guard !chapters.isEmpty else { return }
        chaptersByVideo[videoId] = chapters
    }

    /// Update `currentChapterTitle` from the active chapter at `time`, or clear it
    /// when the video has no (usable) chapters.
    func updateCurrentChapter(for videoId: String, at time: Double) {
        guard let chapters = chaptersByVideo[videoId], ChaptersLogic.hasChapters(chapters) else {
            currentChapterTitle = nil
            return
        }
        currentChapterTitle = ChaptersLogic.current(at: time, in: chapters)?.title
    }
}
