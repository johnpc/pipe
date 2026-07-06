import Testing
import Foundation
@testable import pipe

/// Pure tests for decoding Piped's error envelope — no global state.
struct PipedErrorTests {

    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test func decodesMessageFromErrorBody() {
        let body = data(#"{"error":"org...ParsingException: ...","message":"JSON response is too short"}"#)
        #expect(PipedErrorEnvelope.error(from: body)?.message == "JSON response is too short")
    }

    @Test func fallsBackToErrorFieldWhenMessageAbsent() {
        let body = data(#"{"error":"something broke"}"#)
        #expect(PipedErrorEnvelope.error(from: body)?.message == "something broke")
    }

    @Test func normalStreamBodyIsNotAnError() {
        // A success body has no error/message keys → not an error envelope.
        let body = data(#"{"title":"T","duration":10,"audioStreams":[],"videoStreams":[]}"#)
        #expect(PipedErrorEnvelope.error(from: body) == nil)
    }

    @Test func emptyMessagesAreNotErrors() {
        #expect(PipedErrorEnvelope.error(from: data(#"{"error":"","message":""}"#)) == nil)
    }

    @Test func nonJSONBodyIsNotAnError() {
        #expect(PipedErrorEnvelope.error(from: data("not json at all")) == nil)
    }

    @Test func pipedErrorSurfacesItsMessageAsReason() {
        // A PipedError should carry through Playback's reason mapping verbatim.
        #expect(Playback.errorReason(PipedError(message: "JSON response is too short")) == "JSON response is too short")
    }
}
