import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("ClipboardEngine")
struct ClipboardEngineTests {

    private struct Harness {
        let engine: ClipboardEngine
        let store: InMemoryHistoryStore
        let vault: FakeSecretsVault
        let writer: SpyClipboardWriter
        let paster: SpyPaster
    }

    private func makeHarness(biometrics: Bool = true) -> Harness {
        let vault = FakeSecretsVault(biometricsWillSucceed: biometrics)
        let store = InMemoryHistoryStore()
        let writer = SpyClipboardWriter()
        let paster = SpyPaster()
        let engine = ClipboardEngine(
            capture: CaptureClipUseCase(classifier: SensitivityClassifier(), vault: vault, hashing: FNV1aHashing()),
            generator: PasswordGenerator(randomness: SequenceRandomness(seed: [3, 9, 17, 4, 222, 1, 88, 35])),
            store: store,
            vault: vault,
            writer: writer,
            paster: paster,
            hashing: FNV1aHashing()
        )
        return Harness(engine: engine, store: store, vault: vault, writer: writer, paster: paster)
    }

    private func content(text: String? = nil, kind: ClipKind = .text,
                         markers: Set<PasteboardMarker> = []) -> CapturedContent {
        CapturedContent(kind: kind, text: text, resourceReference: nil, label: nil,
                        sourceApp: "com.example", markers: markers)
    }

    @Test("Ingest stores a plain item and persists it")
    func ingestPlain() async throws {
        let h = makeHarness()
        let item = try await h.engine.ingest(content(text: "hello"))
        #expect(item != nil)
        #expect(await h.engine.snapshot().count == 1)
        #expect(await h.store.storedCount() == 1)
    }

    @Test("Ingest of marked-concealed content is stored as a revealable secret")
    func ingestSecret() async throws {
        let h = makeHarness()
        let item = try #require(try await h.engine.ingest(content(text: "S3cr3t-Pass", markers: [.concealed])))
        #expect(item.isSensitive)
        // Masked in the snapshot, but revealable through the shared vault.
        #expect(item.payload.displayText.contains("\u{2022}"))
        #expect(try await h.engine.reveal(item.id) == "S3cr3t-Pass")
    }

    @Test("Transient content is dropped")
    func ingestTransient() async throws {
        let h = makeHarness()
        let item = try await h.engine.ingest(content(text: "flash", markers: [.transient]))
        #expect(item == nil)
        #expect(await h.engine.snapshot().isEmpty)
    }

    @Test("Pasting a plain item sends its text with no auto-clear")
    func pastePlain() async throws {
        let h = makeHarness()
        let item = try #require(try await h.engine.ingest(content(text: "plain text")))
        try await h.engine.paste(item.id, into: FocusedFieldInfo(isSecureField: false, appBundleID: nil))
        let pastes = await h.paster.pastes
        #expect(pastes.count == 1)
        #expect(pastes.first?.text == "plain text")
        #expect(pastes.first?.autoClear == nil)
    }

    @Test("Pasting a secret into a secure field needs no biometrics and auto-clears")
    func pasteSecretSecureField() async throws {
        let h = makeHarness(biometrics: false) // biometrics would fail…
        let item = try #require(try await h.engine.ingest(content(text: "topsecret", markers: [.concealed])))
        try await h.engine.paste(item.id, into: FocusedFieldInfo(isSecureField: true, appBundleID: "com.apple.Safari"))
        let pastes = await h.paster.pastes
        #expect(pastes.first?.text == "topsecret")
        #expect(pastes.first?.autoClear != nil)
    }

    @Test("Pasting a secret into a non-secure field is refused when biometrics fail")
    func pasteSecretNonSecureDenied() async throws {
        let h = makeHarness(biometrics: false)
        let item = try #require(try await h.engine.ingest(content(text: "topsecret", markers: [.concealed])))
        await #expect(throws: SecretsVaultError.authenticationFailed) {
            try await h.engine.paste(item.id, into: FocusedFieldInfo(isSecureField: false, appBundleID: nil))
        }
    }

    @Test("Pin persists the updated item")
    func pin() async throws {
        let h = makeHarness()
        let item = try #require(try await h.engine.ingest(content(text: "keep")))
        try await h.engine.pin(item.id)
        #expect(await h.engine.snapshot().first { $0.id == item.id }?.pinned == true)
        let reloaded = try await h.store.load().first { $0.id == item.id }
        #expect(reloaded?.pinned == true)
    }

    @Test("Remove deletes from history and store")
    func remove() async throws {
        let h = makeHarness()
        let item = try #require(try await h.engine.ingest(content(text: "bye")))
        try await h.engine.remove(item.id)
        #expect(await h.engine.snapshot().isEmpty)
        #expect(await h.store.storedCount() == 0)
    }

    @Test("Bootstrap loads persisted items")
    func bootstrap() async throws {
        let h = makeHarness()
        try await h.store.upsert(ClipItem(
            id: UUID(), kind: .text, createdAt: Date(timeIntervalSince1970: 5),
            sourceApp: nil, sensitivity: .normal, payload: .plain("restored"), contentHash: "r"
        ))
        try await h.engine.bootstrap()
        #expect(await h.engine.snapshot().contains { $0.contentHash == "r" })
    }

    @Test("Generate then use a password: stored as secret + written to clipboard + revealable")
    func generateAndUse() async throws {
        let h = makeHarness()
        let generated = try await h.engine.generatePassword(.characters(CharacterPolicy(length: 20)))
        #expect(generated.value.count == 20)

        let item = try await h.engine.useGeneratedPassword(generated)
        #expect(item.isSensitive)
        #expect(await h.engine.snapshot().contains { $0.id == item.id })

        let writes = await h.writer.writes
        #expect(writes.last?.text == generated.value)
        #expect(writes.last?.autoClear != nil)
        #expect(try await h.engine.reveal(item.id) == generated.value)
    }

    @Test("Search matches plain text but not secret plaintext")
    func search() async throws {
        let h = makeHarness()
        _ = try await h.engine.ingest(content(text: "meeting about apples"))
        _ = try await h.engine.ingest(content(text: "apples-secret-key-Z9", markers: [.concealed]))
        let results = await h.engine.search("apples")
        #expect(results.count == 1)
    }
}
