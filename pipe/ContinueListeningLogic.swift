import Foundation

/// Pure selection of "Continue Listening" items so it's unit-testable.
enum ContinueListeningLogic {
    /// In-progress items: have a meaningful resume position (past the intro,
    /// before the end). `items` is assumed newest-first (RecentsStore order);
    /// result preserves that order and is capped.
    static func inProgress(_ items: [RecentItem], limit: Int = 10) -> [RecentItem] {
        let picked = items.filter { item in
            guard item.duration > 0 else { return false }
            let fraction = item.timestamp / Double(item.duration)
            return item.timestamp > 5 && fraction < 0.9
        }
        return Array(picked.prefix(limit))
    }
}
