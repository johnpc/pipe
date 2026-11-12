import SwiftUI
import AVKit

/// A video surface backed by `AVPlayerViewController` so playback supports
/// Picture-in-Picture — including starting automatically when the app is
/// backgrounded mid-video. SwiftUI's `VideoPlayer` cannot do PiP, hence the
/// representable wrapper. `VideoSurfaceCoordinator` keeps audio playing when
/// the app is backgrounded without PiP.
struct PiPVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    var log: PlaybackLog = .shared

    func makeCoordinator() -> VideoSurfaceCoordinator {
        VideoSurfaceCoordinator(log: log)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        // Float into PiP automatically when the app goes to the background while
        // a video is playing inline.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        controller.delegate = context.coordinator
        context.coordinator.attach(controller, player: player)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.attach(controller, player: player)
    }
}
