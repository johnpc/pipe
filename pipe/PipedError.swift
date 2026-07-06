import Foundation

/// An error the Piped instance itself reported. Piped answers HTTP 200 with a
/// body like `{"error":"...ParsingException...","message":"JSON response is too
/// short"}` when it can't extract a video (throttled/broken upstream). Decoding
/// that as a `StreamResponse` fails with an opaque "data couldn't be read"; this
/// surfaces the instance's real message instead, so logs name the true cause.
struct PipedError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

/// The `{error, message}` envelope Piped returns on failure. All-optional so it
/// only counts as an error when a message/error string is actually present —
/// a normal success body simply yields nils.
struct PipedErrorEnvelope: Decodable {
    let error: String?
    let message: String?

    /// The best human message, or nil when this isn't an error body.
    var reportedMessage: String? {
        if let message, !message.isEmpty { return message }
        if let error, !error.isEmpty { return error }
        return nil
    }

    /// If `data` is a Piped error envelope, the `PipedError` it represents.
    static func error(from data: Data) -> PipedError? {
        guard let envelope = try? JSONDecoder().decode(PipedErrorEnvelope.self, from: data),
              let message = envelope.reportedMessage else { return nil }
        return PipedError(message: message)
    }
}
