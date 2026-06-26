import Foundation
import Testing
import CryptoKit
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("EnvelopeVault")
struct EnvelopeVaultTests {

    private func makeVault(gate: any BiometricGate = AllowingGate()) throws -> (EnvelopeVault, InMemoryCiphertextStore) {
        let store = InMemoryCiphertextStore()
        let vault = EnvelopeVault(
            keyAgreement: try SoftwareKeyAgreement(),
            gate: gate,
            store: store
        )
        return (vault, store)
    }

    @Test("Store then reveal round-trips the plaintext")
    func roundTrip() async throws {
        let (vault, _) = try makeVault()
        let secret = try await vault.store(plaintext: "correct horse battery", context: "passphrase", reason: .highEntropy)
        #expect(secret.preview.masked.contains("\u{2022}"))
        #expect(try await vault.reveal(secret.ciphertext) == "correct horse battery")
    }

    @Test("Paste into a secure field needs no biometrics")
    func pasteSecureField() async throws {
        let (vault, _) = try makeVault(gate: DenyingGate()) // would fail if prompted
        let secret = try await vault.store(plaintext: "S3cr3t", context: "password", reason: nil)
        let target = FocusedFieldInfo(isSecureField: true, appBundleID: "com.apple.Safari")
        #expect(try await vault.decryptForPaste(secret.ciphertext, target: target) == "S3cr3t")
    }

    @Test("Paste into a non-secure field degrades to Touch ID")
    func pasteNonSecureField() async throws {
        let secret0Store = InMemoryCiphertextStore()
        let key = try SoftwareKeyAgreement()
        let allowing = EnvelopeVault(keyAgreement: key, gate: AllowingGate(), store: secret0Store)
        let denying = EnvelopeVault(keyAgreement: key, gate: DenyingGate(), store: secret0Store)

        let secret = try await allowing.store(plaintext: "S3cr3t", context: "password", reason: nil)
        let target = FocusedFieldInfo(isSecureField: false, appBundleID: "com.apple.TextEdit")

        #expect(try await allowing.decryptForPaste(secret.ciphertext, target: target) == "S3cr3t")
        await #expect(throws: SecretsVaultError.authenticationFailed) {
            try await denying.decryptForPaste(secret.ciphertext, target: target)
        }
    }

    @Test("Reveal is refused when biometrics fail")
    func revealDenied() async throws {
        let (vault, _) = try makeVault(gate: DenyingGate())
        let secret = try await vault.store(plaintext: "x", context: "password", reason: nil)
        await #expect(throws: SecretsVaultError.authenticationFailed) {
            try await vault.reveal(secret.ciphertext)
        }
    }

    @Test("Purge removes the secret")
    func purge() async throws {
        let (vault, _) = try makeVault()
        let secret = try await vault.store(plaintext: "x", context: "password", reason: nil)
        try await vault.purge(secret.ciphertext)
        await #expect(throws: SecretsVaultError.notFound) {
            try await vault.reveal(secret.ciphertext)
        }
    }

    @Test("Persisted record contains no plaintext")
    func ciphertextHasNoPlaintext() async throws {
        let (vault, store) = try makeVault()
        let plaintext = "TopSecretValue123"
        let secret = try await vault.store(plaintext: plaintext, context: "password", reason: nil)
        let record = try #require(await store.snapshot()[secret.ciphertext.id])
        #expect(!record.payload.contains(Data(plaintext.utf8)))
        #expect(record.wrappedDataKey != Data(plaintext.utf8))
    }

    @Test("Each store produces unique ciphertext")
    func uniqueCiphertext() async throws {
        let (vault, store) = try makeVault()
        let a = try await vault.store(plaintext: "same", context: "c", reason: nil)
        let b = try await vault.store(plaintext: "same", context: "c", reason: nil)
        let snap = await store.snapshot()
        #expect(snap[a.ciphertext.id]?.payload != snap[b.ciphertext.id]?.payload)
    }

    @Test("A different key-agreement key cannot decrypt")
    func keyIsolation() async throws {
        let store = InMemoryCiphertextStore()
        let vaultA = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: store)
        let vaultB = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: store)
        let secret = try await vaultA.store(plaintext: "secret", context: "c", reason: nil)
        // vaultB holds a different KEK, so unwrapping the data key fails. This is exactly
        // the "secret stored under an earlier/lost KEK" case — it must surface as the
        // domain `.cryptographyFailed`, not a leaked CryptoKitError, so the UI can explain it.
        await #expect(throws: SecretsVaultError.cryptographyFailed) {
            try await vaultB.reveal(secret.ciphertext)
        }
    }

    @Test("Secure Enclave round-trips when available (smoke test)")
    func secureEnclaveSmoke() async throws {
        guard SecureEnclaveKeyAgreement.isAvailable,
              let seKey = try? SecureEnclaveKeyAgreement() else {
            // No usable Secure Enclave in this environment (e.g. unsigned test binary).
            return
        }
        let vault = EnvelopeVault(keyAgreement: seKey, gate: AllowingGate(), store: InMemoryCiphertextStore())
        let secret = try await vault.store(plaintext: "enclave-backed", context: "password", reason: nil)
        #expect(try await vault.reveal(secret.ciphertext) == "enclave-backed")
    }
}
