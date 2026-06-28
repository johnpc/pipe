import Foundation

/// Signature of a download operation that reports fractional progress (0...1).
typealias DownloadOperation = (_ remote: URL, _ dest: URL, _ onProgress: @escaping (Double) -> Void) async throws -> Void

/// A `URLSessionDownloadDelegate`-backed downloader that streams progress to a
/// callback, bridged to async/await. Used as the real downloader in the app;
/// tests inject a stub of the same `DownloadOperation` shape.
final class ProgressDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var onProgress: ((Double) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    /// Download `remote`, reporting progress, and move the result to `dest`.
    func download(_ remote: URL, to dest: URL, onProgress: @escaping (Double) -> Void) async throws {
        self.onProgress = onProgress
        let tempURL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            self.continuation = cont
            session.downloadTask(with: remote).resume()
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        // Deliver progress on the main actor (the store updates @Published state).
        DispatchQueue.main.async { [onProgress] in onProgress?(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Move synchronously here: the temp file is deleted when this returns.
        do {
            let stable = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: stable)
            continuation?.resume(returning: stable)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil }
    }

    /// The app's default download operation, conforming to `DownloadOperation`.
    static let operation: DownloadOperation = { remote, dest, onProgress in
        try await ProgressDownloader().download(remote, to: dest, onProgress: onProgress)
    }
}
