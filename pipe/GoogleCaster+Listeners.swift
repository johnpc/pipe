import Foundation

#if canImport(GoogleCast)
import GoogleCast

extension GoogleCaster {
    /// SDK-state snapshot logged when the user taps Cast, so a "nothing happens"
    /// tap is explained by the real state (castState 0 = no devices; discovery
    /// inactive usually means local-network permission was denied).
    var diagnostics: [String: String] {
        [
            "castState": String(GCKCastContext.sharedInstance().castState.rawValue),
            "deviceCount": String(discovery.deviceCount),
            "discoveryActive": String(discovery.discoveryActive),
        ]
    }

    /// Bounce discovery to force a fresh mDNS sweep for receivers. Also re-trips
    /// the Local Network prompt, so a user who dismissed it (or never saw it) gets
    /// another chance from the "Search Again" affordance.
    func rescan() {
        localNetworkNudge.trigger()
        discovery.stopDiscovery()
        discovery.startDiscovery()
    }

    /// Configure the shared Cast context. Idempotent so a repeat call (previews,
    /// tests) doesn't crash. Called once at launch from `pipeApp`.
    static func bootstrap() {
        guard !GCKCastContext.isSharedInstanceInitialized() else { return }
        // Discover by the media NAMESPACE, not by the CC1AD845 application ID.
        // An app-ID criterion filters to devices advertising that receiver's mDNS
        // subtype — which idle Chromecasts/Shields do NOT advertise (confirmed:
        // the Shield publishes plain _googlecast._tcp with no CC1AD845 subtype),
        // so discovery found nothing. Every media-capable receiver supports the
        // standard media namespace, so this finds them all; we still launch the
        // default media receiver on connect.
        let criteria = GCKDiscoveryCriteria(namespaces: [castMediaNamespace])
        let options = GCKCastOptions(discoveryCriteria: criteria)
        // Suspend discovery when backgrounded to save battery.
        options.suspendSessionsWhenBackgrounded = true
        // Discover receivers eagerly at launch. Without this the SDK defaults to
        // deferring discovery until the first tap on a GCKUICastButton — which we
        // don't use — so devices would never be found and the picker would no-op.
        options.startDiscoveryAfterFirstTapOnCastButton = false
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

/// Builds the SDK's `GCKMediaInformation` from our pure `CastMedia`. The only
/// place media metadata is translated into `GCK*` types.
enum CastMediaBuilder {
    static func info(from media: CastMedia) -> GCKMediaInformation {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(media.title, forKey: kGCKMetadataKeyTitle)
        metadata.setString(media.artist, forKey: kGCKMetadataKeySubtitle)
        if let thumb = URL(string: media.thumbnail) {
            metadata.addImage(GCKImage(url: thumb, width: 480, height: 360))
        }
        let builder = GCKMediaInformationBuilder(contentURL: URL(string: media.url) ?? URL(fileURLWithPath: "/"))
        builder.streamType = .buffered
        builder.contentType = media.contentType
        builder.metadata = metadata
        return builder.build()
    }
}
#endif
