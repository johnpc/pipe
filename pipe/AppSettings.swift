import Foundation
import Combine

/// User-configurable app settings, persisted to UserDefaults.
/// Holds the Piped instance base URL and recent search history.
class AppSettings: ObservableObject {
    @Published var instanceURL: String { didSet { persistInstance() } }
    @Published private(set) var searchHistory: [String] = []
    @Published var offlineMode: Bool { didSet { defaults.set(offlineMode, forKey: offlineKey) } }

    private let defaults: UserDefaults
    private let instanceKey = "pipedInstanceURL"
    private let historyKey = "searchHistory"
    private let offlineKey = "offlineMode"
    static let maxHistory = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.instanceURL = defaults.string(forKey: instanceKey) ?? AppSettings.defaultInstance
        self.offlineMode = defaults.bool(forKey: offlineKey)
        if let saved = defaults.stringArray(forKey: historyKey) {
            searchHistory = saved
        }
        // Keep the live network base in sync with the configured instance.
        pipedBase = SettingsLogic.normalizedInstance(instanceURL)
    }

    nonisolated deinit {}

    static let defaultInstance = "https://pipedapi.jpc.io"

    private func persistInstance() {
        let normalized = SettingsLogic.normalizedInstance(instanceURL)
        defaults.set(normalized, forKey: instanceKey)
        pipedBase = normalized
    }

    /// Record a search term at the front of history (deduped, capped).
    func recordSearch(_ term: String) {
        let updated = SettingsLogic.addingSearch(term, to: searchHistory, max: AppSettings.maxHistory)
        guard updated != searchHistory else { return }
        searchHistory = updated
        defaults.set(updated, forKey: historyKey)
    }

    func clearHistory() {
        searchHistory = []
        defaults.removeObject(forKey: historyKey)
    }

    /// Reset the instance URL to the default.
    func resetInstance() {
        instanceURL = AppSettings.defaultInstance
    }
}
