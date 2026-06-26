import Foundation

/// Port providing cryptographically-secure random bytes.
///
/// The domain depends only on this protocol; the production adapter wraps
/// `SecRandomCopyBytes`, while tests inject a deterministic implementation so
/// password generation becomes reproducible (TDD).
public protocol RandomnessPort: Sendable {
    /// Returns exactly `count` random bytes (`count >= 0`).
    func randomBytes(count: Int) -> [UInt8]
}

extension RandomnessPort {
    /// Uniformly-distributed `UInt64` drawn from 8 random bytes.
    func randomUInt64() -> UInt64 {
        var value: UInt64 = 0
        for byte in randomBytes(count: 8) {
            value = (value << 8) | UInt64(byte)
        }
        return value
    }

    /// Unbiased index in `0..<upperBound` via rejection sampling.
    ///
    /// Modulo of a raw random number is biased; we reject the top, non-uniform
    /// slice so every index is equally likely.
    func uniformIndex(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        while true {
            let candidate = randomUInt64()
            if candidate < limit {
                return Int(candidate % bound)
            }
        }
    }

    /// Fisher–Yates shuffle driven by this randomness source.
    func shuffled<T>(_ input: [T]) -> [T] {
        guard input.count > 1 else { return input }
        var array = input
        var i = array.count - 1
        while i > 0 {
            let j = uniformIndex(upperBound: i + 1)
            array.swapAt(i, j)
            i -= 1
        }
        return array
    }
}
