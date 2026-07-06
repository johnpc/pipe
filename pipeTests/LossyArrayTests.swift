import Testing
import Foundation
@testable import pipe

/// Pure decode tests for the lossy array wrapper — no global state.
struct LossyArrayTests {

    private struct Item: Codable, Equatable { let id: Int; let name: String }
    private struct Holder: Codable, Equatable { @LossyArray var items: [Item]? }

    private func decode(_ json: String) throws -> Holder {
        try JSONDecoder().decode(Holder.self, from: Data(json.utf8))
    }

    @Test func keepsAllWellFormedElements() throws {
        let h = try decode(#"{"items":[{"id":1,"name":"a"},{"id":2,"name":"b"}]}"#)
        #expect(h.items == [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
    }

    @Test func dropsOnlyTheMalformedElement() throws {
        // Middle element is missing the required "name" — the rest must survive.
        let h = try decode(#"{"items":[{"id":1,"name":"a"},{"id":2},{"id":3,"name":"c"}]}"#)
        #expect(h.items == [Item(id: 1, name: "a"), Item(id: 3, name: "c")])
    }

    @Test func absentKeyDecodesToNil() throws {
        let h = try decode(#"{}"#)
        #expect(h.items == nil)
    }

    @Test func emptyArrayDecodesToEmpty() throws {
        let h = try decode(#"{"items":[]}"#)
        #expect(h.items == [])
    }

    @Test func roundTripsThroughEncode() throws {
        let original = Holder(items: [Item(id: 1, name: "a")])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Holder.self, from: data) == original)
    }
}
