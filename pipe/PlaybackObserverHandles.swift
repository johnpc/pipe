import AVFoundation

/// The handles for everything observing the live `AVPlayer`, grouped so the
/// player state carries one value instead of seven loose tokens. Installed in
/// `installPlaybackObservers`, torn down in `teardownPlaybackObservers`.
struct PlaybackObserverHandles {
    var time: Any?
    var end: Any?
    var failedEnd: Any?
    var stall: Any?
    var status: NSKeyValueObservation?
    var itemStatus: NSKeyValueObservation?
    /// Periodic observer that auto-skips SponsorBlock segments.
    var sponsor: Any?
}
