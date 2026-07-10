import Foundation

extension Playback {
    /// Row-level "Cast to TV" action: present the device picker so the user can
    /// pick a TV, and start the video playing. If a receiver is already connected
    /// this plays straight on the TV; otherwise playback starts locally and hands
    /// off automatically once the user finishes connecting (see
    /// `PlayerState.attachCast`). Sharing one helper keeps all six list views'
    /// call sites identical.
    @MainActor
    static func cast(videoId: String, player: PlayerState, toast: ToastManaging? = nil) {
        player.cast?.presentDevicePicker()
        Task { await run(videoId: videoId, action: .play, player: player, toast: toast) }
    }
}
