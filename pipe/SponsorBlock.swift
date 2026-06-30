import Foundation

/// Raw SponsorBlock API segment: `segment` is `[start, end]` in seconds.
struct SponsorSegmentDTO: Decodable {
    let segment: [Double]
    let category: String
}

/// A normalized sponsor segment to skip during playback.
struct SponsorSegment: Equatable {
    let start: Double
    let end: Double
}

/// Pure SponsorBlock decisions — unit-testable without a player or network.
enum SponsorBlockLogic {
    /// The categories we ask SponsorBlock to return (sponsors, self-promo,
    /// interaction reminders, intros/outros, previews, off-topic music).
    static let categories = ["sponsor", "selfpromo", "interaction", "intro", "outro", "preview", "music_offtopic"]

    /// Normalize API DTOs into valid segments (exactly two finite bounds with
    /// end after start); drop anything malformed.
    static func parse(_ dtos: [SponsorSegmentDTO]) -> [SponsorSegment] {
        dtos.compactMap { dto in
            guard dto.segment.count == 2 else { return nil }
            let (start, end) = (dto.segment[0], dto.segment[1])
            guard start.isFinite, end.isFinite, end > start else { return nil }
            return SponsorSegment(start: start, end: end)
        }
    }

    /// End of the segment covering `time` (so the caller seeks there), or nil
    /// when skipping is disabled or no segment applies. The 0.5s guard before a
    /// segment's end prevents a seek/observer thrash loop at the boundary.
    static func skipTarget(at time: Double, in segments: [SponsorSegment], enabled: Bool) -> Double? {
        guard enabled else { return nil }
        return segments.first { time >= $0.start && time < $0.end - 0.5 }?.end
    }
}
