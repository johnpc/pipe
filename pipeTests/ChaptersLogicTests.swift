import Testing
import Foundation
@testable import pipe

struct ChaptersLogicTests {
    private let chapters = [
        Chapter(title: "Intro", start: 0, image: nil),
        Chapter(title: "Middle", start: 60, image: nil),
        Chapter(title: "End", start: 120, image: nil),
    ]

    @Test func currentIndexPicksLastStartedChapter() {
        #expect(ChaptersLogic.currentIndex(at: 0, in: chapters) == 0)
        #expect(ChaptersLogic.currentIndex(at: 59, in: chapters) == 0)
        #expect(ChaptersLogic.currentIndex(at: 60, in: chapters) == 1)
        #expect(ChaptersLogic.currentIndex(at: 200, in: chapters) == 2)
    }

    @Test func currentIndexNilBeforeFirstStart() {
        let later = [Chapter(title: "A", start: 30, image: nil)]
        #expect(ChaptersLogic.currentIndex(at: 10, in: later) == nil)
    }

    @Test func currentIndexNilWhenEmpty() {
        #expect(ChaptersLogic.currentIndex(at: 5, in: []) == nil)
    }

    @Test func currentReturnsChapter() {
        #expect(ChaptersLogic.current(at: 65, in: chapters)?.title == "Middle")
        #expect(ChaptersLogic.current(at: 5, in: [])?.title == nil)
    }

    @Test func hasChaptersRequiresMoreThanOne() {
        #expect(ChaptersLogic.hasChapters(nil) == false)
        #expect(ChaptersLogic.hasChapters([]) == false)
        #expect(ChaptersLogic.hasChapters([chapters[0]]) == false)
        #expect(ChaptersLogic.hasChapters(chapters) == true)
    }

    @Test func chapterIdentifiableByStart() {
        #expect(chapters[1].id == 60)
    }
}
