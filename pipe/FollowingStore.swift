import Foundation
import Combine

class FollowingStore: ObservableObject {
    @Published var channels: [FollowedChannel] = []
    private let key = "followedChannels"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // See RecentsStore: opt the deinit out of MainActor isolation to avoid a
    // crashing async executor hop on deallocation.
    nonisolated deinit {}

    func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FollowedChannel].self, from: data) {
            channels = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(channels) {
            defaults.set(data, forKey: key)
        }
    }
    
    func follow(_ channel: FollowedChannel) {
        guard !channels.contains(where: { $0.id == channel.id }) else { return }
        channels.append(channel)
        save()
    }
    
    func unfollow(_ id: String) {
        channels.removeAll { $0.id == id }
        save()
    }
    
    func isFollowing(_ id: String) -> Bool {
        channels.contains { $0.id == id }
    }
}
