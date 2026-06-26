import Foundation
import CryptoKit
import ActunaCopyPasteCore

/// Production `ContentHashing` backed by Apple CryptoKit SHA-256.
///
/// The most-native Apple hashing primitive (audit verdict). The pure-Swift
/// `FNV1aHashing` in the core stays as the dependency-free default used by tests.
public struct CryptoKitHashing: ContentHashing {
    public init() {}

    public func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
