import Testing
import Foundation
import AVKit
@testable import pipe

/// Detaching the player from the on-screen video surface while backgrounded,
/// so iOS doesn't pause the audio, and reattaching on return.
@MainActor
struct VideoSurfaceCoordinatorTests {
    private let center = NotificationCenter()
    private let buffer = RingBufferSink(capacity: 50)

    private func attached() -> (VideoSurfaceCoordinator, AVPlayerViewController, AVPlayer) {
        let coordinator = VideoSurfaceCoordinator(log: PlaybackLog(buffer: buffer), center: center)
        let controller = AVPlayerViewController()
        let player = AVPlayer()
        coordinator.attach(controller, player: player)
        return (coordinator, controller, player)
    }

    @Test func attachShowsThePlayerOnce() {
        let (coordinator, controller, player) = attached()
        #expect(controller.player === player)
        coordinator.attach(controller, player: player)  // same player: no churn
        #expect(controller.player === player)
        let other = AVPlayer()
        coordinator.attach(controller, player: other)
        #expect(controller.player === other)
        #expect(coordinator.player === other)
    }

    @Test func backgroundingDetachesAndForegroundingReattaches() {
        let (coordinator, controller, player) = attached()
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(controller.player == nil)
        #expect(coordinator.player === player)  // remembered for the return trip
        #expect(buffer.exportText().contains("[video] detach for background"))
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(controller.player === player)
        #expect(buffer.exportText().contains("[video] reattach"))
    }

    @Test func pictureInPictureKeepsItsPlayerWhileBackgrounded() {
        let (coordinator, controller, player) = attached()
        coordinator.playerViewControllerWillStartPictureInPicture(controller)
        #expect(coordinator.isPiPActive)
        coordinator.didEnterBackground()
        #expect(controller.player === player)
        coordinator.playerViewControllerDidStopPictureInPicture(controller)
        #expect(!coordinator.isPiPActive)
        coordinator.didEnterBackground()
        #expect(controller.player == nil)
        #expect(buffer.exportText().contains("[pip] start"))
        #expect(buffer.exportText().contains("[pip] stop"))
    }

    @Test func foregroundWithoutADetachIsANoop() {
        let (coordinator, controller, player) = attached()
        coordinator.willEnterForeground()
        #expect(controller.player === player)
        #expect(!buffer.exportText().contains("reattach"))
    }

    @Test func lifecycleWithoutASurfaceIsANoop() {
        let coordinator = VideoSurfaceCoordinator(log: PlaybackLog(buffer: buffer), center: center)
        coordinator.didEnterBackground()
        coordinator.willEnterForeground()
        #expect(buffer.exportText().isEmpty)
    }

    @Test func surfaceBuildsWithTheCoordinatorAsDelegate() {
        let surface = PiPVideoPlayer(player: AVPlayer(), log: PlaybackLog(buffer: buffer))
        let coordinator = surface.makeCoordinator()
        #expect(coordinator.player == nil)
    }
}
