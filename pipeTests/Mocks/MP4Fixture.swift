import Foundation

/// Hand-built fragmented-MP4 heads (`ftyp moov sidx`) for index tests, so
/// edge cases (versions, offsets, truncation) don't need binary fixtures.
enum MP4Fixture {
    /// `ftyp` + `moov` stubs: 16 bytes each.
    static let headerLength = 32

    static func be32(_ v: Int) -> Data { Data([UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)]) }
    static func be64(_ v: Int) -> Data { be32(v >> 32) + be32(v & 0xffff_ffff) }

    static func box(_ type: String, payload: Data, largesize: Bool = false) -> Data {
        if largesize {
            return be32(1) + Data(type.utf8) + be64(16 + payload.count) + payload
        }
        return be32(8 + payload.count) + Data(type.utf8) + payload
    }

    static func sidxLength(count: Int, version: Int = 0) -> Int {
        8 + 12 + (version == 0 ? 8 : 16) + 4 + count * 12
    }

    /// A head whose `sidx` lists `fragments` as (size, duration-in-timescale).
    static func indexed(fragments: [(Int, Int)], timescale: Int, version: Int = 0, firstOffset: Int = 0) -> Data {
        var sidx = Data([UInt8(version), 0, 0, 0]) + be32(1) + be32(timescale)
        sidx += version == 0 ? be32(0) + be32(firstOffset) : be64(0) + be64(firstOffset)
        sidx += Data([0, 0]) + Data([UInt8(fragments.count >> 8), UInt8(fragments.count & 0xff)])
        for (size, duration) in fragments {
            sidx += be32(size) + be32(duration) + be32(0)
        }
        return box("ftyp", payload: Data(count: 8)) + box("moov", payload: Data(count: 8)) + box("sidx", payload: sidx)
    }
}
