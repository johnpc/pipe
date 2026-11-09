import Foundation

/// UserDefaults keys for the player's persisted state and preferences.
extension PlayerState {
    var queueKey: String { "savedQueue" }
    var indexKey: String { "savedQueueIndex" }
    var speedKey: String { "playbackSpeed" }
    var sponsorKey: String { "sponsorBlockEnabled" }
    var videoModeKey: String { "videoMode" }
}
