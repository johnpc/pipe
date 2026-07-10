import Foundation

#if canImport(GoogleCast)
import GoogleCast

extension GoogleCaster {
    /// Configure the shared Cast context. Idempotent so a repeat call (previews,
    /// tests) doesn't crash. Called once at launch from `pipeApp`.
    static func bootstrap() {
        guard !GCKCastContext.isSharedInstanceInitialized() else { return }
        let criteria = GCKDiscoveryCriteria(applicationID: castDefaultReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        // Suspend discovery when backgrounded to save battery.
        options.suspendSessionsWhenBackgrounded = true
        GCKCastContext.setSharedInstanceWith(options)
    }
}

/// SDK callback wiring for `GoogleCaster`. Session, discovery, and media-status
/// changes all funnel back through the store's handlers so `CastStore` republishes
/// connection state and receiver time to the UI. Kept separate so the core
/// `GoogleCaster` stays focused and under the line limit.
extension GoogleCaster: GCKSessionManagerListener, GCKDiscoveryManagerListener, GCKRemoteMediaClientListener {
    func sessionManager(_ manager: GCKSessionManager, didStart session: GCKSession) {
        (session as? GCKCastSession)?.remoteMediaClient?.add(self)
        onStateChange?()
    }

    func sessionManager(_ manager: GCKSessionManager, didResumeSession session: GCKSession) {
        (session as? GCKCastSession)?.remoteMediaClient?.add(self)
        onStateChange?()
    }

    func sessionManager(_ manager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        onStateChange?()
    }

    func didUpdateDeviceList() { onStateChange?() }

    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        onStateChange?()
        onTimeChange?()
    }
}

/// Builds the SDK's `GCKMediaInformation`/`GCKMediaQueueItem` from our pure
/// `CastMedia`. The only place media metadata is translated into `GCK*` types.
enum CastMediaBuilder {
    static func item(from media: CastMedia) -> GCKMediaQueueItem {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(media.title, forKey: kGCKMetadataKeyTitle)
        metadata.setString(media.artist, forKey: kGCKMetadataKeySubtitle)
        if let thumb = URL(string: media.thumbnail) {
            metadata.addImage(GCKImage(url: thumb, width: 480, height: 360))
        }
        let info = GCKMediaInformationBuilder(contentURL: URL(string: media.url) ?? URL(fileURLWithPath: "/"))
        info.streamType = .buffered
        info.contentType = media.contentType
        info.metadata = metadata
        return GCKMediaQueueItemBuilder().with(info.build()).build()
    }
}

private extension GCKMediaQueueItemBuilder {
    func with(_ info: GCKMediaInformation) -> GCKMediaQueueItemBuilder {
        mediaInformation = info
        return self
    }
}
#endif
