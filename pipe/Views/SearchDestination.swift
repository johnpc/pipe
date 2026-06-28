import SwiftUI

/// Routes a tapped search result to its screen (channel / playlist / video).
/// Extracted from SearchView so the branchy navigation closure is a
/// single-purpose, render-testable view (keeps SearchView's CRAP low).
struct SearchDestination: View {
    let item: SearchItem
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore

    var body: some View {
        if item.isChannel {
            ChannelView(channelId: item.channelId, player: player, following: following, recents: recents)
        } else if item.isPlaylist {
            PlaylistView(playlistId: item.playlistId, title: item.displayTitle, player: player, saved: .shared)
        } else {
            DetailView(videoId: item.videoId, player: player)
        }
    }
}
