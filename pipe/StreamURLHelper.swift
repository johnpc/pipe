import Foundation
import UIKit

/// Rewrites a Piped proxy URL to point directly at the upstream host carried in
/// its `host=` query param, and strips that param. Generalized to any proxy
/// origin (not a hardcoded instance) so it keeps working when the configured
/// Piped instance changes. Returns the input unchanged if there's no `host=`.
func rewriteProxyHost(_ url: String) -> String {
    guard let r = url.range(of: "host=([^&]+)", options: .regularExpression),
          let h = url[r].split(separator: "=").last else { return url }
    let host = String(h)
    var result = url
    if let origin = result.range(of: "^https?://[^/]+/", options: .regularExpression) {
        result.replaceSubrange(origin, with: "https://\(host)/")
    }
    return result
        .replacingOccurrences(of: "host=\(host)&", with: "")
        .replacingOccurrences(of: "&host=\(host)", with: "")
}

/// Best progressive MP4 video stream URL (full A/V), proxy-rewritten.
func getStreamUrl(_ s: StreamResponse) -> String {
    let url = s.videoStreams.first { $0.mimeType.contains("mp4") && $0.videoOnly == false }?.url ?? ""
    return rewriteProxyHost(url)
}

/// Best audio-only stream URL, proxy-rewritten. Prefers the highest-bitrate
/// MP4/M4A audio track; falls back to the highest-bitrate audio of any type, then
/// to an empty string when the response carries no audio streams (caller falls
/// back to the video URL). Lets audio playback avoid downloading video frames.
func getAudioStreamUrl(_ s: StreamResponse) -> String {
    let mp4 = s.audioStreams.filter { $0.mimeType.contains("mp4") || $0.mimeType.contains("m4a") }
    let best = mp4.max { $0.bitrate < $1.bitrate } ?? s.audioStreams.max { $0.bitrate < $1.bitrate }
    guard let url = best?.url else { return "" }
    return rewriteProxyHost(url)
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

func htmlToAttributedString(_ html: String) -> AttributedString {
    let data = Data(html.utf8)
    if let nsAttr = try? NSAttributedString(
        data: data,
        options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
        documentAttributes: nil
    ) {
        return AttributedString(nsAttr)
    }
    return AttributedString(html)
}
