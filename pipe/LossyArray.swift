import Foundation

/// Decodes a JSON array element-by-element, dropping any element that fails to
/// decode instead of letting one bad entry fail the whole container.
///
/// Piped occasionally puts a malformed entry in a stream's `relatedStreams` —
/// e.g. a "Mix"/radio playlist with `title` and `duration` absent. Our
/// `RelatedStream` requires those, so without this a single junk entry made an
/// otherwise-playable video's entire response undecodable ("The data couldn't
/// be read because it is missing."). Wrapping the array makes decode resilient:
/// the good videos survive, the junk row is skipped.
@propertyWrapper
struct LossyArray<Element: Codable & Equatable>: Codable, Equatable {
    var wrappedValue: [Element]?

    init(wrappedValue: [Element]?) { self.wrappedValue = wrappedValue }

    /// A throwaway that consumes one element so the unkeyed container advances
    /// past a value we couldn't decode (decode() doesn't advance on failure).
    private struct Skip: Codable {}

    init(from decoder: Decoder) throws {
        guard var container = try? decoder.unkeyedContainer() else {
            wrappedValue = nil
            return
        }
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        wrappedValue = elements
    }

    func encode(to encoder: Encoder) throws { try wrappedValue.encode(to: encoder) }
}

extension KeyedDecodingContainer {
    /// Make an absent key decode to an empty wrapper (nil) rather than throwing,
    /// so the property behaves like the optional it wraps.
    func decode<T>(_ type: LossyArray<T>.Type, forKey key: Key) throws -> LossyArray<T> {
        (try? decodeIfPresent(LossyArray<T>.self, forKey: key)) ?? LossyArray(wrappedValue: nil)
    }
}
