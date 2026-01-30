import Foundation

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

func formatTime(_ s: Double) -> String {
    guard s.isFinite, s >= 0 else { return "0:00" }
    let m = Int(s) / 60, sec = Int(s) % 60
    return String(format: "%d:%02d", m, sec)
}
