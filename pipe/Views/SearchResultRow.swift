import SwiftUI

/// One search result row — routes by item type (channel / playlist / video) to
/// the right row + navigation. Extracted from SearchView so the branchy closure
/// is a single-purpose, render-testable view (keeps SearchView's CRAP low).
struct SearchResultRow: View {
    let item: SearchItem
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var saved: SavedStore
    @ObservedObject var downloads: DownloadStore
    let onToggleFollow: () -> Void
    let actions: SearchRowActions

    var body: some View {
        if item.isChannel {
            HStack {
                NavigationLink(value: item) { ChannelRow(item: item) }
                    .accessibilityIdentifier("channelRow")
                Button(action: onToggleFollow) {
                    Image(systemName: following.isFollowing(item.channelId) ? "heart.fill" : "heart")
                        .foregroundColor(following.isFollowing(item.channelId) ? .red : .gray)
                }.buttonStyle(.plain).accessibilityIdentifier("followButton")
            }
        } else if item.isPlaylist {
            NavigationLink(value: item) { PlaylistRow(item: item.asPlaylistItem) }
                .accessibilityIdentifier("playlistRow")
        } else {
            NavigationLink(value: item) {
                AudioRow(item: item, isCompleted: recents.isCompleted(videoId: item.videoId),
                         resumeTime: recents.resumeTime(videoId: item.videoId),
                         onPlay: { actions.play(item) }, onQueue: { actions.queue(item) },
                         onPlayNext: { actions.playNext(item) },
                         isSaved: saved.isSaved(item.videoId), onToggleSave: { Haptics.tap(); actions.toggleSave(item) },
                         isDownloaded: downloads.isDownloaded(item.videoId), onToggleDownload: { Haptics.tap(); actions.toggleDownload(item) })
            }
        }
    }
}

/// The per-video actions a search row triggers, injected so the row view stays
/// free of business logic.
struct SearchRowActions {
    let play: (SearchItem) -> Void
    let queue: (SearchItem) -> Void
    let playNext: (SearchItem) -> Void
    let toggleSave: (SearchItem) -> Void
    let toggleDownload: (SearchItem) -> Void
}
