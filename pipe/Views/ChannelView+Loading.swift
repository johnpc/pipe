import SwiftUI

/// Channel + tab loading, split out of ChannelView so the view file stays under
/// the line limit and the network flow lives in one focused place.
extension ChannelView {
    func load() async {
        failed = false
        if let result = try? await PipedAPI.channel(channelId) {
            channel = result
        } else if channel == nil {
            failed = true
        }
    }

    /// Load a secondary tab. The "playlists" tab returns playlist references; any
    /// other tab returns videos.
    func loadTab(_ name: String, data: String) {
        loadingTab = true
        Task {
            if name == "playlists" {
                let playlists = (try? await PipedAPI.playlistTab(data)) ?? []
                await MainActor.run { tabPlaylists = playlists; loadingTab = false }
            } else {
                let response = try? await PipedAPI.channelTab(data)
                await MainActor.run { tabContent = response?.content ?? []; loadingTab = false }
            }
        }
    }
}
