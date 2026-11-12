import Foundation

/// Big-endian field readers for MP4 box parsing. Callers bounds-check first.
enum MP4Bytes {
    static func u16(_ b: [UInt8], _ i: Int) -> UInt16 { UInt16(b[i]) << 8 | UInt16(b[i + 1]) }
    static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
    }
    /// Clamped to `Int` so a malformed huge size can't trap.
    static func u64(_ b: [UInt8], _ i: Int) -> Int {
        Int(clamping: UInt64(u32(b, i)) << 32 | UInt64(u32(b, i + 4)))
    }
    static func type(_ b: [UInt8], _ i: Int) -> String {
        String(decoding: b[(i + 4)..<(i + 8)], as: UTF8.self)
    }
}
