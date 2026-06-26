import Foundation

/// Produces a stable, non-reversible hash of content for de-duplication.
/// Kept as a port so the production adapter can use SHA-256 while tests stay
/// deterministic and dependency-free.
public protocol ContentHashing: Sendable {
    func hash(_ input: String) -> String
}

/// Default FNV-1a hashing. De-duplication is not security-sensitive, so this
/// fast, dependency-free, deterministic hash suffices; production may inject a
/// SHA-256 adapter instead.
public struct FNV1aHashing: ContentHashing {
    public init() {}

    public func hash(_ input: String) -> String {
        var value: UInt64 = 1469598103934665603 // offset basis
        for byte in input.utf8 {
            value ^= UInt64(byte)
            value = value &* 1099511628211 // FNV prime
        }
        return String(value, radix: 16)
    }
}

extension SecretReason {
    /// Short human label used in masked-preview context strings.
    public var label: String {
        switch self {
        case .privateKey: return "private key"
        case .jwt: return "JWT token"
        case .creditCard: return "card number"
        case .apiKey: return "API key"
        case .highEntropy: return "secret"
        }
    }
}
