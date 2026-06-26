import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("ActunaPersistence shared stack")
struct PersistenceStackTests {

    @Test("One container backs both the history and ciphertext stores")
    func sharedContainerBacksBothStores() async throws {
        let (history, ciphertext) = try ActunaPersistence.makeInMemoryStores()

        // History store works.
        let item = ClipItem(id: UUID(), kind: .text, createdAt: Date(timeIntervalSince1970: 1),
                            sourceApp: nil, sensitivity: .normal, payload: .plain("hi"), contentHash: "h")
        try await history.upsert(item)
        #expect(try await history.load().count == 1)

        // Ciphertext store works on the same combined schema.
        let id = UUID()
        let record = EncryptedRecord(ephemeralPublicKey: Data([1]), wrappedDataKey: Data([2]),
                                     payload: Data([3]), context: "c", reason: .apiKey)
        try await ciphertext.put(id, record)
        #expect(try await ciphertext.get(id) == record)
    }

    @Test("End-to-end: vault over the shared stack round-trips a secret")
    func vaultOverSharedStack() async throws {
        let (_, ciphertext) = try ActunaPersistence.makeInMemoryStores()
        let vault = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: ciphertext)
        let secret = try await vault.store(plaintext: "shared-secret", context: "password", reason: nil)
        #expect(try await vault.reveal(secret.ciphertext) == "shared-secret")
    }
}
