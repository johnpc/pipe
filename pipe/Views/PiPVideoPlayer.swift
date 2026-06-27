import SwiftUI
import AVKit

/// A video surface backed by `AVPlayerViewController` so playback supports
/// Picture-in-Picture — including starting automatically when the app is
/// backgrounded mid-video. SwiftUI's `VideoPlayer` cannot do PiP, hence the
/// representable wrapper.
struct PiPVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        // Float into PiP automatically when the app goes to the background while
        // a video is playing inline.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
