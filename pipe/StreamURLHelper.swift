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
    let m = seconds / 60, s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

func formatTime(_ s: Double) -> String {
    guard s.isFinite, s >= 0 else { return "0:00" }
    let m = Int(s) / 60, sec = Int(s) % 60
    return String(format: "%d:%02d", m, sec)
}
