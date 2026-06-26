import Foundation
import CryptoKit
import ActunaCopyPasteCore

/// Native secrets vault using envelope encryption (CryptoKit AES-256-GCM payloads
/// + ECDH-wrapped per-record data keys) with a Secure-Enclave key-agreement
/// provider and a biometric gate. Implements the domain `SecretsVaultPort`.
///
/// Policy:
/// - `reveal`: always requires biometrics.
/// - `decryptForPaste`: a positively-detected secure field pastes with no prompt;
///   any other / unknown target degrades to a biometric gate.
public struct EnvelopeVault: SecretsVaultPort {
    private let keyAgreement: KeyAgreementProvider
    private let gate: BiometricGate
    private let store: CiphertextStore
    private let revealReason: String
    private let pasteReason: String

    public init(
        keyAgreement: KeyAgreementProvider,
        gate: BiometricGate,
        store: CiphertextStore,
        revealReason: String = "Reveal the saved secret",
        pasteReason: String = "Paste the saved secret"
    ) {
        self.keyAgreement = keyAgreement
        self.gate = gate
        self.store = store
        self.revealReason = revealReason
        self.pasteReason = pasteReason
    }

    // HKDF parameters binding the derived wrapping key to this app/scheme version.
    private static let salt = Data("Actuna.CopyPaste.KEK.v1".utf8)
    private static let info = Data("envelope-data-key".utf8)

    public func store(plaintext: String, context: String, reason: SecretReason?) async throws -> Secret {
        let dataKey = SymmetricKey(size: .bits256)
        guard let payload = try AES.GCM.seal(Data(plaintext.utf8), using: dataKey).combined else {
            throw EnvelopeError.sealFailed
        }

        let ephemeral = P256.KeyAgreement.PrivateKey()
        let kekPublic = try P256.KeyAgreement.PublicKey(rawRepresentation: keyAgreement.publicKeyData)
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: kekPublic)
        let wrappingKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Self.salt, sharedInfo: Self.info, outputByteCount: 32
        )
        let dataKeyBytes = dataKey.withUnsafeBytes { Data($0) }
        guard let wrapped = try AES.GCM.seal(dataKeyBytes, using: wrappingKey).combined else {
            throw EnvelopeError.sealFailed
        }

        let id = UUID()
        try await store.put(id, EncryptedRecord(
            ephemeralPublicKey: ephemeral.publicKey.rawRepresentation,
            wrappedDataKey: wrapped,
            payload: payload,
            context: context,
            reason: reason
        ))

        return Secret(
            ciphertext: CiphertextRef(id: id),
            preview: MaskedPreview.make(from: plaintext, context: context),
            reason: reason
        )
    }

    public func reveal(_ ref: CiphertextRef) async throws -> String {
        try await gate.authenticate(reason: revealReason)
        return try await decrypt(ref)
    }

    public func decryptForPaste(_ ref: CiphertextRef, target: FocusedFieldInfo) async throws -> String {
        if target.isSecureField != true {
            try await gate.authenticate(reason: pasteReason) // degrade to Touch ID
        }
        return try await decrypt(ref)
    }

    public func purge(_ ref: CiphertextRef) async throws {
        try await store.delete(ref.id)
    }

    // MARK: - Private

    private func decrypt(_ ref: CiphertextRef) async throws -> String {
        guard let record = try await store.get(ref.id) else { throw SecretsVaultError.notFound }
        do {
            let shared = try keyAgreement.sharedSecret(withEphemeralPublicKey: record.ephemeralPublicKey)
            let wrappingKey = shared.hkdfDerivedSymmetricKey(
                using: SHA256.self, salt: Self.salt, sharedInfo: Self.info, outputByteCount: 32
            )
            let dataKeyData = try AES.GCM.open(AES.GCM.SealedBox(combined: record.wrappedDataKey), using: wrappingKey)
            let dataKey = SymmetricKey(data: dataKeyData)
            let plaintextData = try AES.GCM.open(AES.GCM.SealedBox(combined: record.payload), using: dataKey)
            guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
                throw EnvelopeError.decodeFailed
            }
            return plaintext
        } catch {
            // AES-GCM tag verification failed (a rotated/lost KEK, e.g. a secret stored
            // under an earlier ad-hoc build, or tampered ciphertext) surfaces as
            // `CryptoKitError.authenticationFailure`. Map every crypto failure to a domain
            // error so callers can explain it without depending on CryptoKit's types.
            throw SecretsVaultError.cryptographyFailed
        }
    }
}
