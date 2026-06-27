import Foundation

/// Pure chapter helpers so the timeline logic is unit-testable.
enum ChaptersLogic {
    /// Index of the chapter active at `time` (the last chapter whose start is
    /// ≤ time). Returns nil when there are no chapters or time precedes the first.
    static func currentIndex(at time: Double, in chapters: [Chapter]) -> Int? {
        guard !chapters.isEmpty else { return nil }
        var result: Int? = nil
        for (i, ch) in chapters.enumerated() where Double(ch.start) <= time {
            result = i
        }
        return result
    }

    /// The chapter active at `time`, if any.
    static func current(at time: Double, in chapters: [Chapter]) -> Chapter? {
        guard let i = currentIndex(at: time, in: chapters) else { return nil }
        return chapters[i]
    }

    /// Whether a stream has usable chapters (more than one — a single marker
    /// isn't a meaningful chapter list).
    static func hasChapters(_ chapters: [Chapter]?) -> Bool {
        (chapters?.count ?? 0) > 1
    }
}
