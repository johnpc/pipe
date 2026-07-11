import Foundation

/// User's preferred maximum cast resolution. `.auto` lets the app pick the best
/// available; the capped cases limit selection so a big TV can be told to favor
/// higher quality (or a metered connection lower). What's actually achievable
/// depends on the Piped instance — some serve only low progressive streams.
enum CastQuality: String, CaseIterable, Identifiable {
    case auto, p360 = "360p", p720 = "720p", p1080 = "1080p"
    var id: String { rawValue }

    /// Display label for the picker.
    var label: String { self == .auto ? "Auto (best available)" : rawValue }

    /// Numeric ceiling in pixels of height; nil = no cap (auto).
    var maxHeight: Int? {
        switch self {
        case .auto: return nil
        case .p360: return 360
        case .p720: return 720
        case .p1080: return 1080
        }
    }
}

/// Pure selection of the URL to cast, honoring the user's quality preference.
/// Kept free of the SDK and network so it's exhaustively unit-testable.
enum CastQualityLogic {
    /// Parse the height from a Piped quality string like "1080p" / "360p60".
    static func height(from quality: String) -> Int? {
        let digits = quality.prefix { $0.isNumber }
        return Int(digits)
    }

    /// Pick the best progressive MP4 stream at or below the preferred cap.
    /// Returns the highest-resolution match; if none qualifies (e.g. the cap is
    /// below everything offered), falls back to the lowest available so casting
    /// still works. Empty when there are no progressive MP4 streams at all.
    static func bestURL(from streams: [VideoStream], quality: CastQuality) -> String {
        let progressive = streams.filter { $0.mimeType.contains("mp4") && $0.videoOnly == false }
        guard !progressive.isEmpty else { return "" }
        let sorted = progressive.sorted { (height(from: $0.quality) ?? 0) > (height(from: $1.quality) ?? 0) }
        guard let cap = quality.maxHeight else { return sorted.first?.url ?? "" }
        let atOrBelow = sorted.first { (height(from: $0.quality) ?? 0) <= cap }
        return (atOrBelow ?? sorted.last)?.url ?? ""
    }
}
