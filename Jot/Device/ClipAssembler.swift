import Foundation

/// Rebuilds a clip from the packets a Jot sends on its audio characteristic:
///
///     START  01 | codec u8 (1 = IMA ADPCM) | sample rate u16 LE | total bytes u32 LE
///     DATA   02 | packet number u16 LE (from 0) | audio bytes
///     END    03 | packet count u16 LE | total bytes u32 LE
///
/// A missing or short packet fails the whole clip rather than playing back a gap.
struct ClipAssembler {
    enum Event: Equatable {
        case started
        case finished(adpcm: Data, sampleRate: Int)
        case failed(String)
    }

    private var isActive = false
    private var sampleRate = 0
    private var expectedBytes = 0
    private var nextPacket = 0
    private var audio = Data()

    /// Feeds one notification. Returns an event when a clip starts, finishes or fails.
    mutating func receive(_ packet: Data) -> Event? {
        let bytes = [UInt8](packet)
        switch bytes.first {
        case 0x01:
            guard bytes.count >= 8 else { return fail("START packet too short") }
            guard bytes[1] == 1 else { return fail("unknown codec \(bytes[1])") }
            sampleRate = Self.uint(bytes, at: 2, size: 2)
            expectedBytes = Self.uint(bytes, at: 4, size: 4)
            nextPacket = 0
            audio = Data(capacity: expectedBytes)
            isActive = true
            return .started

        case 0x02:
            guard isActive else { return nil }
            guard bytes.count > 3 else { return fail("empty DATA packet") }
            let number = Self.uint(bytes, at: 1, size: 2)
            guard number == nextPacket else { return fail("missing packet \(nextPacket), got \(number)") }
            audio.append(contentsOf: bytes[3...])
            nextPacket += 1
            guard audio.count <= expectedBytes else { return fail("more audio than the START packet announced") }
            return nil

        case 0x03:
            guard isActive else { return nil }
            isActive = false
            guard bytes.count >= 7 else { return .failed("END packet too short") }
            let count = Self.uint(bytes, at: 1, size: 2)
            let total = Self.uint(bytes, at: 3, size: 4)
            guard count == nextPacket, total == expectedBytes, audio.count == expectedBytes else {
                return .failed("got \(audio.count) of \(expectedBytes) bytes in \(nextPacket) of \(count) packets")
            }
            return .finished(adpcm: audio, sampleRate: sampleRate)

        default:
            return nil
        }
    }

    private mutating func fail(_ reason: String) -> Event {
        isActive = false
        return .failed(reason)
    }

    /// Little-endian unsigned integer of `size` bytes.
    private static func uint(_ bytes: [UInt8], at offset: Int, size: Int) -> Int {
        (0..<size).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
    }
}
