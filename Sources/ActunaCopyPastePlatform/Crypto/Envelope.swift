import Foundation
import CryptoKit
import ActunaCopyPasteCore

/// One encrypted secret, stored as an envelope: the payload is sealed with a
/// per-record random data key, and that data key is wrapped to the vault's
/// key-encryption key via ECDH. No plaintext and no unwrapped key is ever stored.
public struct EncryptedRecord: Sendable, Equatable {
    /// Raw representation of the ephemeral P-256 public key used for ECDH.
    public let ephemeralPublicKey: Data
    /// AES-GCM combined box (nonce‖ciphertext‖tag) of the data key.
    public let wrappedDataKey: Data
    /// AES-GCM combined box of the secret payload.
    public let payload: Data
    public let context: String
    public let reason: SecretReason?

    public init(ephemeralPublicKey: Data, wrappedDataKey: Data, payload: Data, context: String, reason: SecretReason?) {
        self.ephemeralPublicKey = ephemeralPublicKey
        self.wrappedDataKey = wrappedDataKey
        self.payload = payload
        self.context = context
        self.reason = reason
    }
}

/// Supplies the vault's key-encryption key as a P-256 key-agreement endpoint.
/// Production: a Secure-Enclave-resident key (device-bound, non-extractable).
/// The ECDH operation runs inside the Enclave; biometric policy is applied by the
/// vault, not by the key, so paste-into-secure-field needs no prompt.
public protocol KeyAgreementProvider: Sendable {
    /// Raw representation of the KEK public key.
    var publicKeyData: Data { get }
    /// Computes the ECDH shared secret with the given ephemeral public key.
    func sharedSecret(withEphemeralPublicKey ephemeral: Data) throws -> SharedSecret
}

/// Gates an action behind biometric (Touch ID) authentication.
/// Production: LocalAuthentication `LAContext`.
public protocol BiometricGate: Sendable {
    /// Throws `SecretsVaultError.authenticationFailed` / `.authenticationUnavailable`
    /// if the user is not verified.
    func authenticate(reason: String) async throws
}

/// Persists encrypted records (production: SwiftData / encrypted file).
public protocol CiphertextStore: Sendable {
    func put(_ id: UUID, _ record: EncryptedRecord) async throws
    func get(_ id: UUID) async throws -> EncryptedRecord?
    func delete(_ id: UUID) async throws
}

public enum EnvelopeError: Error, Equatable {
    case sealFailed
    case decodeFailed
}
