import Foundation

/// SponsorBlock segment lookup (sponsor.ajay.app). Separate host from the Piped
/// instance, but reuses PipedAPI's injectable `session` so it's stubbable in
/// tests via MockURLProtocol.
extension PipedAPI {
    static let sponsorBlockBase = "https://sponsor.ajay.app"

    /// Build the skipSegments request URL for a video. Pure, so it's testable.
    static func sponsorSegmentsURL(_ videoId: String) -> URL? {
        let cats = SponsorBlockLogic.categories.joined(separator: "&category=")
        return URL(string: "\(sponsorBlockBase)/api/skipSegments?videoID=\(videoId)&category=\(cats)")
    }

    /// Fetch sponsor segments for a video. Returns [] on any error or 404 (the
    /// API 404s when a video has no segments) — skipping is best-effort.
    static func sponsorSegments(_ videoId: String) async -> [SponsorSegment] {
        guard let url = sponsorSegmentsURL(videoId),
              let (data, _) = try? await session.data(from: url),
              let dtos = try? JSONDecoder().decode([SponsorSegmentDTO].self, from: data) else { return [] }
        return SponsorBlockLogic.parse(dtos)
    }
}
