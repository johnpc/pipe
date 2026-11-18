import Foundation
import Combine

/// User-configurable app settings, persisted to UserDefaults.
/// Holds the Piped instance base URL and recent search history.
class AppSettings: ObservableObject {
    @Published var instanceURL: String { didSet { persistInstance() } }
    /// Optional second instance, tried when `instanceURL` can't be reached
    /// ("" = none). See `InstanceFailover`.
    @Published var fallbackInstanceURL: String { didSet { persistFallback() } }
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
    /// Preferred audio language for dubbed videos (English unless changed).
    /// Kept in sync with the `pipedAudioLanguage` global stream selection reads.
    @Published var audioLanguage: String {
        didSet { defaults.set(audioLanguage, forKey: audioLanguageKey); pipedAudioLanguage = audioLanguage }
    }

    private let defaults: UserDefaults
    /// UserDefaults key of the Piped instance base URL (also set by `MockMode`
    /// when a UI test points the app at the local fake backend).
    static let instanceKey = "pipedInstanceURL"
    /// UserDefaults key of the optional fallback instance.
    static let fallbackKey = "pipedFallbackInstanceURL"
    private let historyKey = "searchHistory"
    private let offlineKey = "offlineMode"
    private let diagnosticsKey = "diagnosticsUpload"
    private let castQualityKey = "castQuality"
    private let audioLanguageKey = "audioLanguage"
    static let maxHistory = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A fresh install has no instance; an install from before that rule
        // existed keeps the instance it has been using. The choice is persisted
        // so it is made exactly once.
        let stored = defaults.string(forKey: Self.instanceKey)
        let initial = SettingsLogic.initialInstance(stored: stored, hasPriorData: SettingsLogic.hasPriorData(in: defaults))
        self.instanceURL = initial
        if stored == nil { defaults.set(initial, forKey: Self.instanceKey) }
        self.fallbackInstanceURL = defaults.string(forKey: Self.fallbackKey) ?? AppSettings.noInstance
        self.offlineMode = defaults.bool(forKey: offlineKey)
        self.diagnosticsUpload = defaults.bool(forKey: diagnosticsKey)
        self.castQuality = CastQuality(rawValue: defaults.string(forKey: castQualityKey) ?? "") ?? .auto
        self.audioLanguage = defaults.string(forKey: audioLanguageKey) ?? AudioLanguageLogic.english
        if let saved = defaults.stringArray(forKey: historyKey) {
            searchHistory = saved
        }
        // Keep the live network base in sync with the configured instance.
        pipedBase = SettingsLogic.normalizedInstance(instanceURL)
        pipedFallbackBase = SettingsLogic.normalizedInstance(fallbackInstanceURL)
        pipedCastQuality = castQuality
        pipedAudioLanguage = audioLanguage
    }

    nonisolated deinit {}

    /// pipe ships with no server. A fresh install has an empty instance until
    /// the user enters one (Settings, or the setup screen on Feed/Search).
    static let noInstance = ""
    /// pipe's hosted demo library: the fake Piped backend's static export —
    /// labelled sample clips, no streaming service involved. Offered as an
    /// explicit choice on the setup screen; it is what App Store review uses.
    static let demoInstance = "https://d2554qyjuoitlv.cloudfront.net"
    /// The instance installs from before "no server by default" were using;
    /// kept for them on upgrade (see `SettingsLogic.initialInstance`).
    static let legacyInstance = "https://pipedapi.jpc.io"

    /// Whether the app has somewhere to fetch from.
    var isConfigured: Bool { !instanceURL.isEmpty }

    private func persistInstance() {
        let normalized = SettingsLogic.normalizedInstance(instanceURL)
        defaults.set(normalized, forKey: Self.instanceKey)
        pipedBase = normalized
    }

    private func persistFallback() {
        let normalized = SettingsLogic.normalizedInstance(fallbackInstanceURL)
        defaults.set(normalized, forKey: Self.fallbackKey)
        pipedFallbackBase = normalized
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

    /// Forget the instance: the app goes back to its setup state.
    func clearInstance() {
        instanceURL = AppSettings.noInstance
    }

    /// Point the app at the hosted demo library.
    func useDemoInstance() {
        instanceURL = AppSettings.demoInstance
    }
}
