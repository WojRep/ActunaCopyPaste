import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("VaultKeyProvisioner")
struct VaultKeyProvisionerTests {

    // `preferSecureEnclave: false` forces the software path so tests are
    // deterministic and independent of code-signing / Secure Enclave availability.

    @Test("First run mints a key and persists its blob")
    func firstRunMintsAndPersists() throws {
        let store = FakeKeyBlobStore()
        let key = try VaultKeyProvisioner(store: store).make(preferSecureEnclave: false)

        #expect(store.saveCount == 1)
        #expect(try store.loadBlob() != nil)
        #expect(!key.publicKeyData.isEmpty)
    }

    @Test("Reload reconstructs the same public key without re-persisting")
    func reloadSamePublicKey() throws {
        let store = FakeKeyBlobStore()
        let provisioner = VaultKeyProvisioner(store: store)

        let first = try provisioner.make(preferSecureEnclave: false)
        let second = try provisioner.make(preferSecureEnclave: false)

        #expect(first.publicKeyData == second.publicKeyData)
        #expect(store.saveCount == 1) // only the first run persisted
    }

    @Test("A key reconstructed from the persisted blob decrypts earlier secrets")
    func reconstructedKeyDecryptsAcrossInstances() async throws {
        let blobStore = FakeKeyBlobStore()
        let cipherStore = InMemoryCiphertextStore()

        let key1 = try VaultKeyProvisioner(store: blobStore).make(preferSecureEnclave: false)
        let vault1 = EnvelopeVault(keyAgreement: key1, gate: AllowingGate(), store: cipherStore)
        let secret = try await vault1.store(plaintext: "remember-me", context: "password", reason: nil)

        // Simulate relaunch: fresh provisioner over the same blob + same ciphertext store.
        let key2 = try VaultKeyProvisioner(store: blobStore).make(preferSecureEnclave: false)
        let vault2 = EnvelopeVault(keyAgreement: key2, gate: AllowingGate(), store: cipherStore)

        #expect(try await vault2.reveal(secret.ciphertext) == "remember-me")
    }

    @Test("Delete then make mints a fresh, different key")
    func deleteThenMintFresh() throws {
        let store = FakeKeyBlobStore()
        let first = try VaultKeyProvisioner(store: store).make(preferSecureEnclave: false)
        try store.deleteBlob()
        let second = try VaultKeyProvisioner(store: store).make(preferSecureEnclave: false)

        #expect(first.publicKeyData != second.publicKeyData)
        #expect(store.saveCount == 2)
    }
}
