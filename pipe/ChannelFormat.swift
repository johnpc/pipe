import Foundation

/// Pure formatting for channel metadata, so it's unit-testable.
enum ChannelFormat {
    /// Compact subscriber count: 505_000_000 → "505M subscribers", 12_300 → "12.3K
    /// subscribers", 950 → "950 subscribers". Returns nil for nil or ≤0.
    static func subscribers(_ count: Int?) -> String? {
        guard let count, count > 0 else { return nil }
        let n = Double(count)
        let formatted: String
        switch count {
        case 1_000_000_000...:
            formatted = trim(n / 1_000_000_000) + "B"
        case 1_000_000...:
            formatted = trim(n / 1_000_000) + "M"
        case 1_000...:
            formatted = trim(n / 1_000) + "K"
        default:
            formatted = "\(count)"
        }
        return "\(formatted) subscribers"
    }

    /// One decimal, dropping a trailing ".0".
    private static func trim(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}
