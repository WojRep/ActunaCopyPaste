import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

@Suite("SwiftDataHistoryStore")
struct SwiftDataHistoryStoreTests {

    private func textItem(_ text: String, hash: String, at seconds: TimeInterval, pinned: Bool = false) -> ClipItem {
        ClipItem(id: UUID(), kind: .text, createdAt: Date(timeIntervalSince1970: seconds),
                 sourceApp: "com.example", pinned: pinned, sensitivity: .normal,
                 payload: .plain(text), contentHash: hash)
    }

    @Test("Upsert then load round-trips a plain item")
    func plainRoundTrip() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        let item = textItem("hello", hash: "h1", at: 1)
        try await store.upsert(item)

        let loaded = try await store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == item.id)
        #expect(loaded.first?.payload == .plain("hello"))
        #expect(loaded.first?.contentHash == "h1")
    }

    @Test("Secret items persist masked preview and ciphertext ref, never plaintext")
    func secretRoundTrip() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        let ref = CiphertextRef(id: UUID())
        let preview = MaskedPreview.make(from: "SuperSecret123", context: "14 chars · API key")
        let secret = Secret(ciphertext: ref, preview: preview, reason: .apiKey)
        let item = ClipItem(id: UUID(), kind: .text, createdAt: Date(timeIntervalSince1970: 2),
                            sourceApp: nil, sensitivity: .detectedSecret(reason: .apiKey),
                            payload: .secret(secret), contentHash: "sh")
        try await store.upsert(item)

        let loaded = try #require(try await store.load().first)
        #expect(loaded.sensitivity == .detectedSecret(reason: .apiKey))
        guard case .secret(let s) = loaded.payload else {
            Issue.record("expected secret payload"); return
        }
        #expect(s.ciphertext == ref)
        #expect(s.preview == preview)
        #expect(s.reason == .apiKey)
        #expect(loaded.payload.searchableText == nil)
    }

    @Test("Resource items round-trip")
    func resourceRoundTrip() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        let item = ClipItem(id: UUID(), kind: .image, createdAt: Date(timeIntervalSince1970: 3),
                            sourceApp: nil, sensitivity: .normal,
                            payload: .resource(reference: "/tmp/a.png", label: "a.png"), contentHash: "rh")
        try await store.upsert(item)
        let loaded = try #require(try await store.load().first)
        #expect(loaded.kind == .image)
        #expect(loaded.payload == .resource(reference: "/tmp/a.png", label: "a.png"))
    }

    @Test("Upsert with the same id updates in place")
    func upsertUpdates() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        var item = textItem("first", hash: "h1", at: 1)
        try await store.upsert(item)
        item.pinned = true
        try await store.upsert(item)

        let loaded = try await store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.pinned == true)
    }

    @Test("Load returns items newest first")
    func ordering() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        try await store.upsert(textItem("a", hash: "a", at: 1))
        try await store.upsert(textItem("b", hash: "b", at: 2))
        try await store.upsert(textItem("c", hash: "c", at: 3))
        let hashes = try await store.load().map(\.contentHash)
        #expect(hashes == ["c", "b", "a"])
    }

    @Test("Remove deletes a single item")
    func remove() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        let item = textItem("x", hash: "x", at: 1)
        try await store.upsert(item)
        try await store.upsert(textItem("y", hash: "y", at: 2))
        try await store.remove(id: item.id)
        let hashes = try await store.load().map(\.contentHash)
        #expect(hashes == ["y"])
    }

    @Test("replaceAll swaps the whole contents")
    func replaceAll() async throws {
        let store = try SwiftDataHistoryStore.inMemory()
        try await store.upsert(textItem("old", hash: "old", at: 1))
        try await store.replaceAll([
            textItem("n1", hash: "n1", at: 2),
            textItem("n2", hash: "n2", at: 3)
        ])
        let hashes = Set(try await store.load().map(\.contentHash))
        #expect(hashes == ["n1", "n2"])
    }
}
