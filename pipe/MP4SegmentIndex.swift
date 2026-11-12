import Foundation

/// The byte map of a fragmented MP4 as YouTube serves it (`ftyp moov sidx
/// moof mdat …`): the initialization section plus one entry per fragment, read
/// from the `sidx` box at the head of the file. With it the two adaptive
/// streams can be described to AVPlayer as HLS byte-range segments, which it
/// streams incrementally — building an `AVComposition` from the same URLs made
/// AVFoundation scan the whole file for a sample table (minutes, then failure).
struct MP4SegmentIndex: Equatable {
    struct Fragment: Equatable {
        let offset: Int
        let size: Int
        let duration: Double
    }

    /// Bytes `0..<initLength` are the `ftyp` + `moov` initialization section.
    let initLength: Int
    let fragments: [Fragment]

    enum Failure: Error, Equatable {
        /// The data ended before the `sidx` box did; `needed` bytes would hold it.
        case truncated(needed: Int)
        /// Not an indexed fragmented MP4 (no `sidx` before the media data).
        case noIndex
    }

    /// Walk the top-level boxes until the `sidx` box, then decode it.
    static func parse(_ data: Data) throws -> MP4SegmentIndex {
        let bytes = [UInt8](data)
        var pos = 0
        while pos + 8 <= bytes.count {
            var size = Int(MP4Bytes.u32(bytes, pos))
            var header = 8
            if size == 1 {  // 64-bit "largesize" follows the type
                guard pos + 16 <= bytes.count else { throw Failure.truncated(needed: pos + 16) }
                size = MP4Bytes.u64(bytes, pos + 8)
                header = 16
            }
            guard size >= header else { throw Failure.noIndex }  // 0 = "to end of file": unindexed
            switch MP4Bytes.type(bytes, pos) {
            case "sidx":
                guard pos + size <= bytes.count else { throw Failure.truncated(needed: pos + size) }
                return try parseSidx(bytes, box: pos, header: header, size: size)
            case "moof", "mdat":
                throw Failure.noIndex  // media began without an index
            default:
                pos += size
            }
        }
        throw Failure.truncated(needed: pos + 8)
    }

    /// Decode a `sidx` box (ISO 14496-12 §8.16.3): fragments start right after
    /// the box (plus `first_offset`) and are laid end to end.
    private static func parseSidx(_ bytes: [UInt8], box: Int, header: Int, size: Int) throws -> MP4SegmentIndex {
        var p = box + header
        guard p + 12 <= box + size else { throw Failure.noIndex }
        let version = bytes[p]
        p += 8  // version + flags, reference_ID
        let timescale = Int(MP4Bytes.u32(bytes, p))
        p += 4
        let firstOffset: Int
        if version == 0 {
            firstOffset = Int(MP4Bytes.u32(bytes, p + 4))
            p += 8
        } else {
            guard p + 16 <= box + size else { throw Failure.noIndex }
            firstOffset = MP4Bytes.u64(bytes, p + 8)
            p += 16
        }
        guard p + 4 <= box + size else { throw Failure.noIndex }
        let count = Int(MP4Bytes.u16(bytes, p + 2))
        p += 4  // reserved, reference_count
        guard timescale > 0, count > 0, p + count * 12 <= box + size else { throw Failure.noIndex }
        var offset = box + size + firstOffset
        var fragments: [Fragment] = []
        for _ in 0..<count {
            let referencedSize = Int(MP4Bytes.u32(bytes, p) & 0x7fff_ffff)  // top bit: reference_type
            let duration = Double(MP4Bytes.u32(bytes, p + 4)) / Double(timescale)
            fragments.append(Fragment(offset: offset, size: referencedSize, duration: duration))
            offset += referencedSize
            p += 12
        }
        return MP4SegmentIndex(initLength: box, fragments: fragments)
    }
}
