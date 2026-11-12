import AVKit

/// Keeps audio going when the app is backgrounded while the video surface is
/// on screen. iOS pauses any player still attached to an on-screen video view
/// when the app leaves the foreground — unless Picture in Picture takes it over
/// — so the player is detached on background and reattached on return, Apple's
/// recommended way to keep background audio for an on-screen video. An active
/// PiP window keeps its player.
final class VideoSurfaceCoordinator: NSObject, AVPlayerViewControllerDelegate {
    private let log: PlaybackLog
    private let center: NotificationCenter
    private weak var controller: AVPlayerViewController?
    private(set) var player: AVPlayer?
    private(set) var isPiPActive = false
    private var observers: [NSObjectProtocol] = []

    init(log: PlaybackLog = .shared, center: NotificationCenter = .default) {
        self.log = log
        self.center = center
        super.init()
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.didEnterBackground()
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.willEnterForeground()
            },
        ]
    }

    deinit { observers.forEach { center.removeObserver($0) } }

    /// Show `player` in `controller` (a no-op when it already does).
    func attach(_ controller: AVPlayerViewController, player: AVPlayer) {
        self.controller = controller
        self.player = player
        if controller.player !== player { controller.player = player }
    }

    func didEnterBackground() {
        guard !isPiPActive, let controller, controller.player != nil else { return }
        controller.player = nil
        log.event("video", "detach for background")
    }

    func willEnterForeground() {
        guard let controller, controller.player == nil, let player else { return }
        controller.player = player
        log.event("video", "reattach")
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPiPActive = true
        log.event("pip", "start")
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPiPActive = false
        log.event("pip", "stop")
    }
}
