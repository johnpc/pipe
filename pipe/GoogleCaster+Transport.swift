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
        log.event("cast", "loadMedia", fields: ["url": media.url, "type": media.contentType])
        // Track the load so a receiver-side failure (e.g. it can't fetch the
        // media URL) is logged instead of hanging silently on a loader.
        let request = client.loadMedia(CastMediaBuilder.info(from: media), with: options)
        request.delegate = self
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

extension GoogleCaster: GCKRequestDelegate {
    public func requestDidComplete(_ request: GCKRequest) {
        log.event("cast", "loadOK")
    }
    public func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        log.event("cast", "loadFailed", fields: ["error": error.localizedDescription, "code": "\(error.code)"])
    }
    public func request(_ request: GCKRequest, didAbortWith abortReason: GCKRequestAbortReason) {
        log.event("cast", "loadAborted", fields: ["reason": "\(abortReason)"])
    }
}
#endif
