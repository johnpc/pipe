import Foundation

/// Remote diagnostics endpoint configuration for the pipe-logs backend
/// (API Gateway → Lambda → S3, AWS account 566092841021, us-west-2).
///
/// The API key ships in the app: it only throttles casual abuse of the public
/// write endpoint, it is not a secret. Uploads are still opt-in via Settings.
enum DiagnosticsConfig {
    static let endpoint = URL(string: "https://cplhg4wbzk.execute-api.us-west-2.amazonaws.com/prod/logs")

    /// The ingest API key, injected at build time from `Secrets.xcconfig` via
    /// `INFOPLIST_KEY_PipeLogsAPIKey` (never committed — see the repo README for
    /// how to fetch it from AWS). Empty when the secret isn't configured.
    static var apiKey: String {
        (Bundle.main.infoDictionary?["PipeLogsAPIKey"] as? String) ?? ""
    }

    /// Build the opt-in remote sink, or nil if the endpoint/key isn't configured.
    static func makeRemoteSink(identity: DeviceIdentity) -> RemoteLogSink? {
        guard let endpoint, !apiKey.isEmpty else { return nil }
        return RemoteLogSink(endpoint: endpoint, apiKey: apiKey, identity: identity)
    }
}
