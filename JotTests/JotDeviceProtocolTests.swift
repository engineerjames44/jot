import Foundation
import Testing
@testable import Jot

struct JotDeviceProtocolTests {
    // MARK: - IMA ADPCM

    /// The firmware's encoder (Firmware/V1/jot_v1_clip), ported so the decoder
    /// can be checked against it.
    private func encode(_ samples: [Int16]) -> Data {
        var predictor = 0, index = 0
        var out = Data()
        var pending: UInt8?
        for sample in samples {
            var step = IMAADPCM.stepTable[index]
            var diff = Int(sample) - predictor
            var code = 0
            if diff < 0 { code = 8; diff = -diff }
            var delta = step >> 3
            if diff >= step { code |= 4; diff -= step; delta += step }
            step >>= 1
            if diff >= step { code |= 2; diff -= step; delta += step }
            step >>= 1
            if diff >= step { code |= 1; delta += step }
            predictor += code & 8 != 0 ? -delta : delta
            predictor = min(max(predictor, -32768), 32767)
            index = min(max(index + IMAADPCM.indexTable[code], 0), 88)
            if let low = pending {
                out.append(low | UInt8(code) << 4)
                pending = nil
            } else {
                pending = UInt8(code)
            }
        }
        return out
    }

    @Test func decodesWhatTheFirmwareEncodes() {
        let tone = (0..<1600).map { Int16(8000 * sin(Double($0) * 2 * .pi * 440 / 16000)) }
        let decoded = IMAADPCM.decode(encode(tone))
        #expect(decoded.count == tone.count)
        // ADPCM is lossy; after the first few samples it tracks within a small error.
        let error = zip(tone.dropFirst(50), decoded.dropFirst(50)).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(error < 800)
    }

    @Test func lowNibbleComesFirst() {
        // 0x70: low nibble 0 (+step/8), high nibble 7 (large positive step).
        let samples = IMAADPCM.decode(Data([0x70]))
        #expect(samples.count == 2)
        #expect(samples[0] < samples[1])
    }

    // MARK: - Packets

    private func start(rate: Int = 16000, total: Int) -> Data {
        Data([0x01, 1, UInt8(rate & 0xFF), UInt8(rate >> 8)] + (0..<4).map { UInt8((total >> (8 * $0)) & 0xFF) })
    }

    private func data(_ number: Int, _ bytes: [UInt8]) -> Data {
        Data([0x02, UInt8(number & 0xFF), UInt8(number >> 8)] + bytes)
    }

    private func end(count: Int, total: Int) -> Data {
        Data([0x03, UInt8(count & 0xFF), UInt8(count >> 8)] + (0..<4).map { UInt8((total >> (8 * $0)) & 0xFF) })
    }

    @Test func assemblesAClip() {
        var assembler = ClipAssembler()
        #expect(assembler.receive(start(total: 5)) == .started)
        #expect(assembler.receive(data(0, [1, 2, 3])) == nil)
        #expect(assembler.receive(data(1, [4, 5])) == nil)
        #expect(assembler.receive(end(count: 2, total: 5)) == .finished(adpcm: Data([1, 2, 3, 4, 5]), sampleRate: 16000))
    }

    @Test func readsTheEndPacketFromTheDevice() {
        // The END packet seen in nRF Connect: 229 packets, 28,544 bytes.
        var assembler = ClipAssembler()
        _ = assembler.receive(start(total: 28544))
        for number in 0..<228 { _ = assembler.receive(data(number, Array(repeating: 0, count: 125))) }
        _ = assembler.receive(data(228, Array(repeating: 0, count: 28544 - 228 * 125)))
        let result = assembler.receive(Data([0x03, 0xE5, 0x00, 0x80, 0x6F, 0x00, 0x00]))
        #expect(result == .finished(adpcm: Data(count: 28544), sampleRate: 16000))
    }

    @Test func failsOnAMissingPacket() {
        var assembler = ClipAssembler()
        _ = assembler.receive(start(total: 6))
        _ = assembler.receive(data(0, [1, 2]))
        #expect(assembler.receive(data(2, [5, 6])) == .failed("missing packet 1, got 2"))
        // The rest of the broken clip is ignored.
        #expect(assembler.receive(end(count: 3, total: 6)) == nil)
    }

    @Test func failsWhenPacketsWereCutShort() {
        // A small Bluetooth packet size cuts every DATA packet: the totals won't add up.
        var assembler = ClipAssembler()
        _ = assembler.receive(start(total: 10))
        _ = assembler.receive(data(0, [1, 2]))
        _ = assembler.receive(data(1, [3, 4]))
        #expect(assembler.receive(end(count: 2, total: 10)) == .failed("got 4 of 10 bytes in 2 of 2 packets"))
    }

    @Test func ignoresDataBeforeStart() {
        var assembler = ClipAssembler()
        #expect(assembler.receive(data(0, [1])) == nil)
        #expect(assembler.receive(end(count: 1, total: 1)) == nil)
    }

    @Test func normalizesQuietClips() {
        #expect(BLEAudioSource.normalizingGain(for: [0, 400, -1000]) == 16)
        #expect(abs(BLEAudioSource.normalizingGain(for: [0, 29491]) - 1) < 0.01)
        #expect(BLEAudioSource.normalizingGain(for: [0, 0]) == 1)
    }
}
