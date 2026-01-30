import Foundation
import UIKit

func getStreamUrl(_ s: StreamResponse) -> String {
    var url = s.videoStreams.first { $0.mimeType.contains("mp4") && $0.videoOnly == false }?.url ?? ""
    if let r = url.range(of: "host=([^&]+)", options: .regularExpression), let h = url[r].split(separator: "=").last {
        url = url.replacingOccurrences(of: "https://pipedproxy.jpc.io/", with: "https://\(h)/")
        url = url.replacingOccurrences(of: "host=\(h)&", with: "").replacingOccurrences(of: "&host=\(h)", with: "")
    }
    return url
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
