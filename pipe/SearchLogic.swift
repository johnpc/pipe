import Foundation

/// Pure, testable search-related data and helpers, kept out of the view.
enum SearchLogic {
    /// Default popular-channel suggestions shown on the empty search screen.
    static let suggestions = [
        "Joe Rogan Experience",
        "Lex Fridman",
        "Huberman Lab",
        "MrBeast",
        "Veritasium",
        "Marques Brownlee",
        "Kurzgesagt",
        "3Blue1Brown"
    ]

    /// Whether a query is submittable (non-empty after trimming whitespace).
    static func isSubmittable(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
