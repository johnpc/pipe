import Foundation

/// A video's offline state, derived by `DownloadStore.state(for:)` so a row
/// renders from one value instead of consulting three collections.
enum DownloadState: Equatable {
    case none
    case downloading(Double)
    case downloaded(DownloadedItem)

    var isDownloading: Bool { if case .downloading = self { return true }; return false }
    var isDownloaded: Bool { if case .downloaded = self { return true }; return false }
    /// Download progress (0...1) while downloading; nil otherwise.
    var progress: Double? { if case let .downloading(p) = self { return p }; return nil }
}
