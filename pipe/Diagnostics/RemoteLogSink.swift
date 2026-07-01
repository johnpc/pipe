import Foundation

/// Opt-in sink that uploads structured records to the pipe-logs backend
/// (API Gateway → Lambda → S3). Batches entries and flushes on a threshold so
/// we don't POST per event. Off unless the user enables diagnostics upload.
final class RemoteLogSink: PlaybackLogSink {
    private let endpoint: URL
    private let apiKey: String
    private let identity: DeviceIdentity
    private let session: URLSession
    private let batchSize: Int
    private let queue = DispatchQueue(label: "com.johncorser.pipe.remotelog")
    private var pending: [PlaybackLogEntry] = []

    init(endpoint: URL, apiKey: String, identity: DeviceIdentity,
         session: URLSession = .shared, batchSize: Int = 5) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.identity = identity
        self.session = session
        self.batchSize = max(1, batchSize)
        observeAppLifecycle()
    }

    func write(_ entry: PlaybackLogEntry) {
        queue.async {
            self.pending.append(entry)
            if self.pending.count >= self.batchSize { self.flushLocked() }
        }
    }

    /// Upload whatever is buffered (e.g. when the app backgrounds). Passive
    /// listening emits few events, so time/lifecycle flushes — not just the
    /// batch threshold — are what actually get logs off the device.
    func flush() { queue.async { self.flushLocked() } }

    private func flushLocked() {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll()
        guard let body = try? JSONSerialization.data(withJSONObject: RemoteLogSink.payload(batch, identity: identity)) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.httpBody = body
        session.dataTask(with: req).resume()
    }

    /// Build the request payload — a pure function so it's unit-testable.
    static func payload(_ entries: [PlaybackLogEntry], identity: DeviceIdentity) -> [String: Any] {
        [
            "deviceId": identity.deviceId,
            "sessionId": identity.sessionId,
            "appVersion": identity.appVersion,
            "records": entries.map { entry -> [String: Any] in
                [
                    "ts": Int(entry.time.timeIntervalSince1970 * 1000),
                    "category": entry.category,
                    "message": entry.message,
                    "fields": entry.fields,
                ]
            },
        ]
    }
}
