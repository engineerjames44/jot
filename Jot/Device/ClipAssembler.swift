import Foundation

/// Rebuilds a clip from the packets a Jot sends on its audio characteristic:
///
///     START  01 | codec u8 (1 = IMA ADPCM) | sample rate u16 LE | total bytes u32 LE
///     DATA   02 | packet number u16 LE (from 0) | audio bytes
///     END    03 | packet count u16 LE | total bytes u32 LE
///
/// Packets are sent flat out and some get dropped, so at each END the missing
/// packet numbers are asked for again (`resendRequest`) until the clip is whole.
struct ClipAssembler {
    enum Event: Equatable {
        case started
        case finished(adpcm: Data, sampleRate: Int)
        /// Ask the device for these packets; it resends them, then END again.
        case resend([Int])
        case failed(String)
    }

    /// Most packet numbers in one resend request (fits a 128-byte write).
    static let maxResend = 60
    /// Rounds of asking again before giving up on a clip.
    static let maxRounds = 12

    private(set) var isActive = false
    /// Rounds of resending this clip took, for diagnostics.
    private(set) var rounds = 0
    private var sampleRate = 16000
    private var packets: [Int: Data] = [:]

    /// Feeds one notification. Returns an event when a clip starts, needs
    /// packets resent, finishes or fails.
    mutating func receive(_ packet: Data) -> Event? {
        let bytes = [UInt8](packet)
        switch bytes.first {
        case 0x01:
            guard bytes.count >= 8 else { return nil }
            guard bytes[1] == 1 else { return fail("unknown codec \(bytes[1])") }
            begin()
            sampleRate = Self.uint(bytes, at: 2, size: 2)
            return .started

        case 0x02:
            guard bytes.count > 3 else { return nil }
            // A dropped START shouldn't lose the clip: the END carries the totals.
            if !isActive { begin() }
            let number = Self.uint(bytes, at: 1, size: 2)
            if packets[number] == nil { packets[number] = Data(bytes[3...]) }
            return nil

        case 0x03:
            guard isActive, bytes.count >= 7 else { return nil }
            let count = Self.uint(bytes, at: 1, size: 2)
            let total = Self.uint(bytes, at: 3, size: 4)
            let missing = (0..<count).filter { packets[$0] == nil }
            if missing.isEmpty {
                let audio = (0..<count).reduce(into: Data(capacity: total)) { $0.append(packets[$1]!) }
                guard audio.count == total else { return fail("got \(audio.count) of \(total) bytes") }
                isActive = false
                return .finished(adpcm: audio, sampleRate: sampleRate)
            }
            return askAgain(for: missing)

        default:
            return nil
        }
    }

    /// Nothing arrived for a while mid-clip (the END itself may be lost):
    /// an empty request makes the device send END again.
    mutating func stalled() -> Event? {
        guard isActive else { return nil }
        return askAgain(for: [])
    }

    private mutating func askAgain(for missing: [Int]) -> Event {
        rounds += 1
        guard rounds <= Self.maxRounds else {
            return fail("still missing \(missing.count) packets after \(Self.maxRounds) tries")
        }
        return .resend(Array(missing.prefix(Self.maxResend)))
    }

    private mutating func begin() {
        isActive = true
        rounds = 0
        sampleRate = 16000
        packets = [:]
    }

    private mutating func fail(_ reason: String) -> Event {
        isActive = false
        return .failed(reason)
    }

    /// The bytes to write to the resend characteristic for `packets`.
    static func resendRequest(_ packets: [Int]) -> Data {
        Data([0x04, UInt8(packets.count)] + packets.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8 & 0xFF)] })
    }

    /// Little-endian unsigned integer of `size` bytes.
    private static func uint(_ bytes: [UInt8], at offset: Int, size: Int) -> Int {
        (0..<size).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
    }
}
