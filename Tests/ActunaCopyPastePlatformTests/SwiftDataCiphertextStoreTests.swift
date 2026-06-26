import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("SwiftDataCiphertextStore")
struct SwiftDataCiphertextStoreTests {

    /// Deterministic record so value-equality round-trips are assertable.
    private func record(_ tag: String, reason: SecretReason? = nil) -> EncryptedRecord {
        EncryptedRecord(
            ephemeralPublicKey: Data("\(tag)-eph".utf8),
            wrappedDataKey: Data("\(tag)-wrap".utf8),
            payload: Data("\(tag)-payload".utf8),
            context: "\(tag) · context",
            reason: reason
        )
    }

    @Test("Put then get round-trips an encrypted record")
    func roundTrip() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let id = UUID()
        let rec = record("a", reason: .apiKey)
        try await store.put(id, rec)

        let loaded = try #require(try await store.get(id))
        #expect(loaded == rec)
        #expect(loaded.reason == .apiKey)
    }

    @Test("Put with the same id updates in place")
    func upsertUpdates() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let id = UUID()
        try await store.put(id, record("first"))
        try await store.put(id, record("second", reason: .jwt))

        let loaded = try #require(try await store.get(id))
        #expect(loaded == record("second", reason: .jwt))
    }

    @Test("Get on a missing id returns nil")
    func missingIsNil() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        #expect(try await store.get(UUID()) == nil)
    }

    @Test("Delete removes the record")
    func delete() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let id = UUID()
        try await store.put(id, record("x"))
        try await store.delete(id)
        #expect(try await store.get(id) == nil)
    }

    @Test("Records are isolated by id")
    func isolationById() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let a = UUID(); let b = UUID()
        try await store.put(a, record("a"))
        try await store.put(b, record("b"))
        #expect(try await store.get(a) == record("a"))
        #expect(try await store.get(b) == record("b"))
    }
}

@Suite("EnvelopeVault + SwiftDataCiphertextStore")
struct EnvelopeVaultPersistenceTests {

    @Test("Store then reveal round-trips through the persistent store")
    func roundTripThroughPersistentStore() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let vault = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: store)
        let secret = try await vault.store(plaintext: "persisted-secret", context: "password", reason: .highEntropy)
        #expect(try await vault.reveal(secret.ciphertext) == "persisted-secret")
    }

    @Test("Purge removes the secret from the persistent store")
    func purgeThroughPersistentStore() async throws {
        let store = try SwiftDataCiphertextStore.inMemory()
        let vault = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: store)
        let secret = try await vault.store(plaintext: "to-purge", context: "password", reason: nil)
        try await vault.purge(secret.ciphertext)
        await #expect(throws: SecretsVaultError.notFound) {
            try await vault.reveal(secret.ciphertext)
        }
    }
}
