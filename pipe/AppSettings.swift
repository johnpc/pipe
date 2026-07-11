import Foundation
import Combine

/// User-configurable app settings, persisted to UserDefaults.
/// Holds the Piped instance base URL and recent search history.
class AppSettings: ObservableObject {
    @Published var instanceURL: String { didSet { persistInstance() } }
    @Published private(set) var searchHistory: [String] = []
    @Published var offlineMode: Bool { didSet { defaults.set(offlineMode, forKey: offlineKey) } }
    /// Upload diagnostic playback logs to the remote collector. Off by default;
    /// opt-in so nothing leaves the device unless the user asks.
    @Published var diagnosticsUpload: Bool { didSet { defaults.set(diagnosticsUpload, forKey: diagnosticsKey) } }
    /// Preferred maximum resolution when casting to a TV. Kept in sync with the
    /// `pipedCastQuality` global the stream selection reads.
    @Published var castQuality: CastQuality {
        didSet { defaults.set(castQuality.rawValue, forKey: castQualityKey); pipedCastQuality = castQuality }
    }

    private let defaults: UserDefaults
    private let instanceKey = "pipedInstanceURL"
    private let historyKey = "searchHistory"
    private let offlineKey = "offlineMode"
    private let diagnosticsKey = "diagnosticsUpload"
    private let castQualityKey = "castQuality"
    static let maxHistory = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.instanceURL = defaults.string(forKey: instanceKey) ?? AppSettings.defaultInstance
        self.offlineMode = defaults.bool(forKey: offlineKey)
        self.diagnosticsUpload = defaults.bool(forKey: diagnosticsKey)
        self.castQuality = CastQuality(rawValue: defaults.string(forKey: castQualityKey) ?? "") ?? .auto
        if let saved = defaults.stringArray(forKey: historyKey) {
            searchHistory = saved
        }
        // Keep the live network base in sync with the configured instance.
        pipedBase = SettingsLogic.normalizedInstance(instanceURL)
        pipedCastQuality = castQuality
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
