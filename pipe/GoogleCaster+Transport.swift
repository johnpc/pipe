import Foundation

#if canImport(GoogleCast)
import GoogleCast

/// Media transport for `GoogleCaster`: load a media item onto the receiver and
/// drive play/pause/seek/stop through its `GCKRemoteMediaClient`. Kept separate
/// from discovery/session lifecycle so each file has one responsibility.
extension GoogleCaster {
    private var remoteMediaClient: GCKRemoteMediaClient? {
        sessionManager.currentCastSession?.remoteMediaClient
    }

    func load(_ media: CastMedia) {
        guard let client = remoteMediaClient else { return }
        let options = GCKMediaLoadOptions()
        options.autoplay = true
        options.playPosition = media.startTime
        client.loadMedia(CastMediaBuilder.info(from: media), with: options)
    }

    func play() { remoteMediaClient?.play() }
    func pause() { remoteMediaClient?.pause() }
    func stop() { remoteMediaClient?.stop() }

    func seek(to time: Double) {
        let options = GCKMediaSeekOptions()
        options.interval = time
        remoteMediaClient?.seek(with: options)
    }
}
#endif
