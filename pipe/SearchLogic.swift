import Foundation

/// Pure, testable search-related data and helpers, kept out of the view.
enum SearchLogic {
    /// How many channel chips the empty search screen offers.
    static let maxSuggestions = 8

    /// Channel suggestions for the empty search screen: the uploaders of what
    /// is trending on the configured instance, deduplicated in order. Nothing
    /// is hardcoded, so the chips describe the instance the user chose — the
    /// demo library shows demo channels, a real instance shows real ones.
    static func channelSuggestions(from trending: [RelatedStream], limit: Int = maxSuggestions) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for name in trending.compactMap(\.uploaderName) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            out.append(trimmed)
            if out.count == limit { break }
        }
        return out
    }

    /// Fetch the suggestions from the instance; empty when it can't be reached
    /// (the empty screen then just shows the field and recent searches).
    static func loadChannelSuggestions() async -> [String] {
        channelSuggestions(from: (try? await PipedAPI.trending()) ?? [])
    }

    /// Whether a query is submittable (non-empty after trimming whitespace).
    static func isSubmittable(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Minimum query length before auto-searching as the user types (avoids
    /// firing on a single stray character).
    static let autoSearchMinLength = 2

    /// Whether a typed query should trigger an automatic (debounced) search.
    static func shouldAutoSearch(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= autoSearchMinLength
    }

    /// Debounce delay (nanoseconds) between keystrokes and an auto-search.
    static let autoSearchDebounceNanos: UInt64 = 350_000_000
}

/// Pure helpers for Settings: instance-URL normalization and search history.
enum SettingsLogic {
    /// Keys whose presence proves the app has been used before the demo default
    /// existed (queue, history, follows, saves, a chosen speed).
    static let priorDataKeys = ["savedQueue", "recentItems", "followedChannels", "savedItems", "playbackSpeed"]

    /// Whether `defaults` carries data from an earlier install. Only *content*
    /// counts: the stores persist empty arrays at launch (before Settings is
    /// created), so a key's mere presence is true on a brand-new install.
    static func hasPriorData(in defaults: UserDefaults) -> Bool {
        priorDataKeys.contains { hasContent(defaults.object(forKey: $0)) }
    }

    /// A stored value that proves use: a non-empty JSON blob or array, or a
    /// chosen (non-zero) number.
    static func hasContent(_ value: Any?) -> Bool {
        switch value {
        case nil: return false
        case let data as Data: return data.count > 2          // more than "[]"
        case let array as [Any]: return !array.isEmpty
        case let number as NSNumber: return number.doubleValue != 0
        default: return true
        }
    }

    /// The instance to start on: the stored choice; else the instance earlier
    /// installs were using (so an upgrade changes nothing for them); else the
    /// demo library for a genuinely fresh install.
    static func initialInstance(stored: String?, hasPriorData: Bool) -> String {
        if let stored, !stored.isEmpty { return stored }
        return hasPriorData ? AppSettings.legacyInstance : AppSettings.defaultInstance
    }

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
