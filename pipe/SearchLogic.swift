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

/// Pure helpers for Settings: instance-URL normalization and search history.
enum SettingsLogic {
    /// Normalize a user-entered instance URL: trim, default scheme to https,
    /// drop a trailing slash. Falls back to the default when blank.
    static func normalizedInstance(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return AppSettings.defaultInstance }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "https://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Whether a draft instance URL is worth enabling "Save" for: non-blank and,
    /// once normalized, a parseable URL with a host.
    static func isValidInstanceDraft(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return URL(string: normalizedInstance(raw))?.host?.isEmpty == false
    }

    /// Insert a search term at the front of history: trimmed, deduped
    /// (case-insensitive), capped at `max`. Returns the original list when the
    /// term is blank.
    static func addingSearch(_ term: String, to history: [String], max: Int) -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return history }
        var updated = history.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > max { updated = Array(updated.prefix(max)) }
        return updated
    }
}
