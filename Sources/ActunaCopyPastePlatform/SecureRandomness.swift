import Foundation
import Security
import ActunaCopyPasteCore

/// Production `RandomnessPort` backed by the Security framework's CSPRNG.
///
/// `SecRandomCopyBytes(kSecRandomDefault, …)` is the most-native Apple source of
/// cryptographically-secure random bytes (audit verdict: preferred over
/// `SystemRandomNumberGenerator` as a security primitive). The domain layer maps
/// these bytes onto the password alphabet with unbiased rejection sampling.
public struct SecureRandomness: RandomnessPort {
    public init() {}

    public func randomBytes(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        // Failing closed: never return weak randomness for security-sensitive use.
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return bytes
    }
}
