import Foundation

/// Best progressive MP4 video stream URL (full A/V), kept in its proxied form.
/// The upstream googlevideo URL the Piped proxy hands back is signed with the
/// IP of the Piped instance that fetched it, not the client's — connecting
/// directly (as this app used to, via a now-removed host-rewrite) makes
/// AVPlayer reach a CDN edge selected for the instance's network path, which
/// often fails to resolve or connect from the device's own network. Routing
/// through the proxy keeps the fetch on the network the URL is actually valid
/// for, same reasoning as `getCastStreamUrl` below.
func getStreamUrl(_ s: StreamResponse) -> String {
    return bestProgressiveMP4URL(s)
}

/// Best progressive MP4 URL **kept in its proxied form** (no host rewrite), for
/// casting. The Chromecast Default Media Receiver fetches media itself through a
/// web context, so it needs a CORS-enabled source: the Piped proxy adds those
/// headers and fetches googlevideo server-side, whereas the rewritten direct
/// googlevideo URL sends no CORS headers and is bound to the phone's IP — which
/// makes the receiver hang on an endless loader. Empty when there's no MP4 track.
func getCastStreamUrl(_ s: StreamResponse) -> String {
    CastQualityLogic.bestURL(from: s.videoStreams, quality: pipedCastQuality)
}

private func bestProgressiveMP4URL(_ s: StreamResponse) -> String {
    s.videoStreams.first { $0.mimeType.contains("mp4") && $0.videoOnly == false }?.url ?? ""
}

/// Best audio-only stream URL, kept in its proxied form (see `getStreamUrl`).
/// Prefers the highest-bitrate MP4/M4A audio track; falls back to the
/// highest-bitrate audio of any type, then to an empty string when the
/// response carries no audio streams (caller falls back to the video URL).
/// Lets audio playback avoid downloading video frames.
func getAudioStreamUrl(_ s: StreamResponse) -> String {
    let mp4 = s.audioStreams.filter { $0.mimeType.contains("mp4") || $0.mimeType.contains("m4a") }
    let best = mp4.max { $0.bitrate < $1.bitrate } ?? s.audioStreams.max { $0.bitrate < $1.bitrate }
    return best?.url ?? ""
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
        return "\(h)h\(m)m"
    } else {
        return "\(m)m\(s)s"
    }
}

func formatUploadDate(_ dateString: String) -> String {
    // Try ISO8601 format first
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    // Already human readable
    return dateString
}

func formatTime(_ s: Double) -> String {
    guard s.isFinite, s >= 0 else { return "0:00" }
    let m = Int(s) / 60, sec = Int(s) % 60
    return String(format: "%d:%02d", m, sec)
}
