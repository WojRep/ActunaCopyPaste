import Foundation
import CryptoKit
import LocalAuthentication
import ActunaCopyPasteCore

/// Key-encryption key resident in the Secure Enclave (device-bound, the private
/// scalar never leaves hardware). Used to wrap per-record data keys via ECDH.
///
/// The key is NOT biometric-gated at the hardware level — that is intentional so
/// `EnvelopeVault` can paste a secret into a password field with no prompt;
/// reveal/non-secure paste is gated by the vault's `BiometricGate` instead.
public struct SecureEnclaveKeyAgreement: KeyAgreementProvider {
    private let privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey

    /// Opaque blob to persist (e.g. in the Keychain) and pass back via `persisted:`.
    public let keyDataRepresentation: Data

    public static var isAvailable: Bool { SecureEnclave.isAvailable }

    public init(persisted: Data? = nil, authenticationContext: LAContext? = nil) throws {
        if let persisted {
            self.privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                dataRepresentation: persisted, authenticationContext: authenticationContext
            )
        } else {
            self.privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                authenticationContext: authenticationContext
            )
        }
        self.keyDataRepresentation = privateKey.dataRepresentation
    }

    public var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    public func sharedSecret(withEphemeralPublicKey ephemeral: Data) throws -> SharedSecret {
        let ephemeralPublic = try P256.KeyAgreement.PublicKey(rawRepresentation: ephemeral)
        return try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublic)
    }
}

/// Software P-256 key-agreement fallback for machines without a usable Secure
/// Enclave (and for tests). The raw key must be stored securely (Keychain) by the
/// caller. Less hardware protection than `SecureEnclaveKeyAgreement`.
public struct SoftwareKeyAgreement: KeyAgreementProvider {
    private let privateKey: P256.KeyAgreement.PrivateKey

    /// Raw private key — persist only in the Keychain.
    public let keyDataRepresentation: Data

    public init(persisted: Data? = nil) throws {
        if let persisted {
            self.privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: persisted)
        } else {
            self.privateKey = P256.KeyAgreement.PrivateKey()
        }
        self.keyDataRepresentation = privateKey.rawRepresentation
    }

    public var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    public func sharedSecret(withEphemeralPublicKey ephemeral: Data) throws -> SharedSecret {
        let ephemeralPublic = try P256.KeyAgreement.PublicKey(rawRepresentation: ephemeral)
        return try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublic)
    }
}
