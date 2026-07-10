import Foundation

/// The Cast receiver app id. `CC1AD845` is Google's Default Media Receiver, which
/// plays progressive MP4/HLS out of the box — no Cast Developer Console
/// registration is needed for v1. Launched on connect.
let castDefaultReceiverAppID = "CC1AD845"

/// The standard Cast media-control namespace. Used as the discovery criterion so
/// we find every media-capable receiver, rather than filtering by an app-ID
/// subtype that idle devices (like the Shield) don't advertise — which is what
/// made discovery come up empty.
let castMediaNamespace = "urn:x-cast:com.google.cast.media"
