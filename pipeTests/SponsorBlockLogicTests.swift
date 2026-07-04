import Testing
@testable import pipe

struct SponsorBlockLogicTests {
    private func dto(_ start: Double, _ end: Double, _ cat: String = "sponsor") -> SponsorSegmentDTO {
        SponsorSegmentDTO(segment: [start, end], category: cat)
    }

    // MARK: - parse

    @Test func parsesValidSegments() {
        let segs = SponsorBlockLogic.parse([dto(10, 20), dto(30, 45)])
        #expect(segs == [SponsorSegment(start: 10, end: 20), SponsorSegment(start: 30, end: 45)])
    }

    @Test func dropsMalformedSegments() {
        let segs = SponsorBlockLogic.parse([
            SponsorSegmentDTO(segment: [5], category: "sponsor"),        // too few
            SponsorSegmentDTO(segment: [5, 4], category: "sponsor"),     // end ≤ start
            SponsorSegmentDTO(segment: [1, 2, 3], category: "sponsor"),  // too many
            dto(1, 2),
        ])
        #expect(segs == [SponsorSegment(start: 1, end: 2)])
    }

    // MARK: - skipTarget

    @Test func skipsToEndWhenInsideSegment() {
        let segs = [SponsorSegment(start: 10, end: 20)]
        #expect(SponsorBlockLogic.skipTarget(at: 12, in: segs, enabled: true) == 20)
    }

    @Test func noSkipOutsideSegment() {
        let segs = [SponsorSegment(start: 10, end: 20)]
        #expect(SponsorBlockLogic.skipTarget(at: 25, in: segs, enabled: true) == nil)
        #expect(SponsorBlockLogic.skipTarget(at: 5, in: segs, enabled: true) == nil)
    }

    @Test func noSkipWithinEndGuard() {
        // Within 0.5s of the end → don't seek (prevents boundary thrash).
        let segs = [SponsorSegment(start: 10, end: 20)]
        #expect(SponsorBlockLogic.skipTarget(at: 19.8, in: segs, enabled: true) == nil)
    }

    @Test func disabledNeverSkips() {
        let segs = [SponsorSegment(start: 10, end: 20)]
        #expect(SponsorBlockLogic.skipTarget(at: 12, in: segs, enabled: false) == nil)
    }

    @Test func picksFirstMatchingSegment() {
        let segs = [SponsorSegment(start: 10, end: 20), SponsorSegment(start: 15, end: 30)]
        #expect(SponsorBlockLogic.skipTarget(at: 16, in: segs, enabled: true) == 20)
    }

    // Regression: a fractional segment end drove a seek storm. Seeking with a
    // 1s timescale truncated the target (20.828 → 20), landing back inside the
    // segment so the 1s observer re-fired the skip forever. Verify that landing
    // at the true fractional end clears the segment (no re-skip), while the old
    // truncated position would still be inside it.
    @Test func landingAtFractionalEndBreaksSkipLoop() {
        let segs = [SponsorSegment(start: 10, end: 20.828)]
        // Precise landing at the fractional end → no further skip.
        #expect(SponsorBlockLogic.skipTarget(at: 20.828, in: segs, enabled: true) == nil)
        // The old truncated position is still inside the segment → would loop.
        #expect(SponsorBlockLogic.skipTarget(at: 20, in: segs, enabled: true) == 20.828)
    }
}
