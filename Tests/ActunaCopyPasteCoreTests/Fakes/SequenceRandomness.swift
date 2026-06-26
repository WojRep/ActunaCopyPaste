import Foundation
@testable import ActunaCopyPasteCore

/// Deterministic `RandomnessPort` for tests: emits bytes from a fixed seed,
/// cycling as needed. Same seed → same byte stream → reproducible passwords.
final class SequenceRandomness: RandomnessPort, @unchecked Sendable {
    private let seed: [UInt8]
    private var index = 0
    private let lock = NSLock()

    init(seed: [UInt8]) {
        self.seed = seed.isEmpty ? [0] : seed
    }

    /// Convenience: all-zero stream (every `uniformIndex` returns 0).
    static var zeros: SequenceRandomness { SequenceRandomness(seed: [0]) }

    func randomBytes(count: Int) -> [UInt8] {
        lock.lock(); defer { lock.unlock() }
        var out = [UInt8]()
        out.reserveCapacity(count)
        for _ in 0..<count {
            out.append(seed[index % seed.count])
            index += 1
        }
        return out
    }
}
