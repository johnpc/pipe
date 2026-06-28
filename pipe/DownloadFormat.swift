import Foundation

/// Pure formatting + sizing helpers for downloads, unit-testable without disk.
enum DownloadFormat {
    /// Human-readable byte size, e.g. "1.2 MB". Returns "0 KB" for nil/zero.
    static func storageText(bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Progress percent (0–100, clamped) from downloaded/total bytes.
    static func percent(received: Int64, total: Int64) -> Int {
        guard total > 0 else { return 0 }
        let pct = Double(received) / Double(total) * 100
        return min(100, max(0, Int(pct)))
    }
}
