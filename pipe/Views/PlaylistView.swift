import SwiftUI

/// A playlist's videos with a Play All action and a Save toggle. Loads on appear.
struct PlaylistView: View {
    let playlistId: String
    let title: String
    @ObservedObject var player: PlayerState
    @ObservedObject var saved: SavedPlaylistsStore
    @State private var state: LoadState<PlaylistResponse> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading: ProgressView()
            case .failed: RetryView { Task { await load() } }
            case .loaded(let playlist):
                List {
                    PlaylistHeader(playlist: playlist, isSaved: saved.isSaved(playlistId),
                                   onPlayAll: { playAll(playlist) }, onToggleSave: { toggleSave(playlist) })
                        .listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
                    ForEach(PlaylistLogic.playableVideos(playlist)) { v in
                        NavigationLink(value: v) {
                            VideoRow(v: v, isCompleted: false, resumeTime: nil,
                                     onPlay: { play(v) }, onQueue: { queue(v) })
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        state = LoadState.from(try? await PipedAPI.playlist(playlistId))
    }

    private func playAll(_ playlist: PlaylistResponse) {
        Task { await PlaylistCoordinator.playAll(PlaylistLogic.playableVideos(playlist), player: player) }
    }

    private func toggleSave(_ playlist: PlaylistResponse) {
        Haptics.tap()
        saved.toggle(SavedPlaylist(playlistId: playlistId, name: playlist.name,
                                   thumbnail: playlist.thumbnailUrl ?? "", uploader: playlist.uploader ?? ""))
    }

    private func play(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .play, player: player) }
    }

    private func queue(_ v: RelatedStream) {
        Task { await Playback.run(videoId: v.videoId, action: .queue, player: player) }
    }
}
