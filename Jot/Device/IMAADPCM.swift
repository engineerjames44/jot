import Foundation

/// Decodes IMA ADPCM as the Jot firmware encodes it: 4 bits per sample, two
/// samples per byte (low nibble first), predictor and step index starting at 0
/// for every clip.
enum IMAADPCM {
    static let indexTable: [Int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
    static let stepTable: [Int] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
        73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
        449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
        2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
        9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
    ]

    static func decode(_ data: Data) -> [Int16] {
        var samples: [Int16] = []
        samples.reserveCapacity(data.count * 2)
        var predictor = 0
        var index = 0

        func decode(_ code: Int) {
            let step = stepTable[index]
            var delta = step >> 3
            if code & 4 != 0 { delta += step }
            if code & 2 != 0 { delta += step >> 1 }
            if code & 1 != 0 { delta += step >> 2 }
            predictor += code & 8 != 0 ? -delta : delta
            predictor = min(max(predictor, -32768), 32767)
            index = min(max(index + indexTable[code], 0), 88)
            samples.append(Int16(predictor))
        }

        for byte in data {
            decode(Int(byte & 0x0F))
            decode(Int(byte >> 4))
        }
        return samples
    }
}
