import Testing
import Foundation
@testable import pipe

// Serialized: the network tests share MockURLProtocol's static requestHandler,
// so they must not run concurrently or they clobber each other's capture box.
@Suite(.serialized)
struct DiagnosticsTests {
    // MARK: - structured entry rendering

    @Test func lineRendersSortedFields() {
        let entry = PlaybackLogEntry(
            time: Date(timeIntervalSince1970: 0),
            category: "end", message: "fired",
            fields: ["expected": "3600", "reached": "1800"]
        )
        // Fields are appended in key order for stable, greppable lines.
        #expect(entry.line.contains("[end] fired expected=3600 reached=1800"))
    }

    @Test func lineWithoutFieldsHasNoTrailingSpace() {
        let entry = PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "c", message: "m", fields: [:])
        #expect(entry.line.hasSuffix("[c] m"))
    }

    // MARK: - device identity

    @Test func deviceIdPersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "ident-\(UUID().uuidString)")!
        let first = DeviceIdentity(defaults: suite, sessionId: "s1")
        let second = DeviceIdentity(defaults: suite, sessionId: "s2")
        #expect(first.deviceId == second.deviceId) // stable per install
        #expect(first.sessionId != second.sessionId) // fresh per launch
    }

    // MARK: - remote payload shape

    @Test func remotePayloadCarriesIdentityAndRecords() {
        let identity = DeviceIdentity(defaults: UserDefaults(suiteName: "p-\(UUID().uuidString)")!, sessionId: "sess")
        let entries = [
            PlaybackLogEntry(time: Date(timeIntervalSince1970: 1), category: "play", message: "start", fields: ["videoId": "v"]),
        ]
        let payload = RemoteLogSink.payload(entries, identity: identity)
        #expect(payload["deviceId"] as? String == identity.deviceId)
        #expect(payload["sessionId"] as? String == "sess")
        let records = payload["records"] as? [[String: Any]]
        #expect(records?.count == 1)
        #expect(records?.first?["category"] as? String == "play")
        #expect(records?.first?["ts"] as? Int == 1000) // epoch millis
        let fields = records?.first?["fields"] as? [String: String]
        #expect(fields?["videoId"] == "v")
    }

    // MARK: - session start capture

    @MainActor
    @Test func sessionStartRecordsInstanceAndReachesSinkAttachedFirst() {
        // Mirrors ContentView's fixed order: attach the sink, THEN log session
        // start — so the event (carrying the Piped instance) is actually
        // uploaded rather than stranded in the on-device buffer only.
        let player = isolatedPlayer()
        let sink = RingBufferSink()
        player.log = PlaybackLog(buffer: sink)

        player.logSessionStart(instance: "https://pipedapi.jpc.io")

        let start = sink.snapshot().first { $0.category == "session" && $0.message == "start" }
        #expect(start != nil, "session start must reach a sink attached before it")
        #expect(start?.fields["instance"] == "https://pipedapi.jpc.io")
    }

    @MainActor
    @Test func sessionStartIsLoggedOnce() {
        let player = isolatedPlayer()
        let sink = RingBufferSink()
        player.log = PlaybackLog(buffer: sink)

        player.logSessionStart(instance: "a")
        player.logSessionStart(instance: "b") // guarded: second call is a no-op

        let starts = sink.snapshot().filter { $0.category == "session" }
        #expect(starts.count == 1)
        #expect(starts.first?.fields["instance"] == "a")
    }

    @Test func payloadEncodesToValidJSON() {
        let identity = DeviceIdentity(defaults: UserDefaults(suiteName: "j-\(UUID().uuidString)")!, sessionId: "s")
        let entries = [PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "c", message: "m", fields: [:])]
        let payload = RemoteLogSink.payload(entries, identity: identity)
        #expect(JSONSerialization.isValidJSONObject(payload))
    }

    // MARK: - remote sink upload (mocked network)

    @Test func flushPostsBatchWithApiKeyHeader() async throws {
        let captured = Captured()
        // Own dedicated protocol (not the shared MockURLProtocol) so this can't
        // race the PipedAPI tests over a static handler under parallel suites.
        CapturingURLProtocol.setHandler { req in
            captured.request = req
            captured.body = req.httpBodyStream.map { Captured.read($0) } ?? req.httpBody
        }
        let identity = DeviceIdentity(defaults: UserDefaults(suiteName: "u-\(UUID().uuidString)")!, sessionId: "sess")
        let sink = RemoteLogSink(
            endpoint: URL(string: "https://example.test/logs")!,
            apiKey: "test-key", identity: identity,
            session: CapturingURLProtocol.makeSession(), batchSize: 2
        )
        // Two writes hit the batch threshold and trigger an automatic flush.
        sink.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "play", message: "start", fields: ["videoId": "v"]))
        sink.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 1), category: "end", message: "fired", fields: [:]))

        try await Task.sleep(nanoseconds: 500_000_000)
        let req = try #require(captured.request)
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "test-key")
        let body = try #require(captured.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["deviceId"] as? String == identity.deviceId)
        #expect((json["records"] as? [Any])?.count == 2)
    }

    @Test func flushUploadsSubThresholdBatch() async throws {
        // Passive listening emits few events, so flush() (lifecycle/timer) must
        // upload even when the batch threshold hasn't been reached.
        let captured = Captured()
        CapturingURLProtocol.setHandler { req in
            captured.request = req
            captured.body = req.httpBodyStream.map { Captured.read($0) } ?? req.httpBody
        }
        let identity = DeviceIdentity(defaults: UserDefaults(suiteName: "f-\(UUID().uuidString)")!, sessionId: "s")
        let sink = RemoteLogSink(
            endpoint: URL(string: "https://example.test/logs")!,
            apiKey: "k", identity: identity,
            session: CapturingURLProtocol.makeSession(), batchSize: 25
        )
        sink.write(PlaybackLogEntry(time: Date(timeIntervalSince1970: 0), category: "play", message: "start", fields: [:]))
        sink.flush() // one event, far below the threshold

        try await Task.sleep(nanoseconds: 500_000_000)
        let req = try #require(captured.request, "flush() should POST even below batch size")
        let body = try #require(captured.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect((json["records"] as? [Any])?.count == 1)
    }
}

/// Thread-safe capture box for the mocked request (URLProtocol runs off-thread).
final class Captured: @unchecked Sendable {
    var request: URLRequest?
    var body: Data?
    static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
