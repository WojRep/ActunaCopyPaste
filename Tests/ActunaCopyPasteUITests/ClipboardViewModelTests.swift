import Foundation
import Testing
import ActunaCopyPasteCore
import ActunaCopyPastePlatform
@testable import ActunaCopyPasteUI

// MARK: - Test doubles for the write-only ports (no real pasteboard in tests).

private struct NoopWriter: ClipboardWriterPort {
    func write(_ text: String, autoClearAfter seconds: TimeInterval?) async throws {}
}
private struct NoopPaster: PastePort {
    func paste(text: String, autoClearAfter seconds: TimeInterval?) async throws {}
}
private struct AllowingGate: BiometricGate {
    func authenticate(reason: String) async throws {}
}

private func makeEngine() throws -> ClipboardEngine {
    let (history, ciphertext) = try ActunaPersistence.makeInMemoryStores()
    let vault = EnvelopeVault(keyAgreement: try SoftwareKeyAgreement(), gate: AllowingGate(), store: ciphertext)
    return ClipboardEngine(
        capture: CaptureClipUseCase(classifier: SensitivityClassifier(), vault: vault, hashing: CryptoKitHashing()),
        generator: PasswordGenerator(randomness: SecureRandomness()),
        store: history,
        vault: vault,
        writer: NoopWriter(),
        paster: NoopPaster(),
        hashing: CryptoKitHashing(),
        autoClearSeconds: nil
    )
}

private func text(_ value: String, markers: Set<PasteboardMarker> = []) -> CapturedContent {
    CapturedContent(kind: .text, text: value, resourceReference: nil, label: nil, sourceApp: nil, markers: markers)
}

@MainActor
@Suite("ClipboardViewModel")
struct ClipboardViewModelTests {

    @Test("Refresh maps domain items to display rows; secrets are masked + carry context")
    func mapsRowsWithMaskedSecret() async throws {
        let engine = try makeEngine()
        _ = try await engine.ingest(text("hello world"))
        _ = try await engine.ingest(text("concealed-value", markers: [.concealed]))

        let vm = ClipboardViewModel(engine: engine)
        await vm.refresh()

        #expect(vm.rows.count == 2)

        let secretRow = try #require(vm.rows.first { $0.isSecret })
        #expect(secretRow.displayText.contains("\u{2022}")) // bullet → masked
        #expect(!secretRow.displayText.contains("concealed-value"))
        #expect(secretRow.secretContext != nil)

        let plainRow = try #require(vm.rows.first { !$0.isSecret })
        #expect(plainRow.displayText == "hello world")
    }

    @Test("Search filters the rows by query")
    func searchFilters() async throws {
        let engine = try makeEngine()
        _ = try await engine.ingest(text("apple pie"))
        _ = try await engine.ingest(text("banana bread"))

        let vm = ClipboardViewModel(engine: engine)
        vm.searchText = "banana"
        await vm.refresh()

        #expect(vm.rows.count == 1)
        #expect(vm.rows.first?.displayText == "banana bread")
    }

    @Test("Pure rows(from:) shows the masked preview, never plaintext")
    func pureMapping() {
        let preview = MaskedPreview.make(from: "VerySecretValue", context: "15 chars · API key")
        let secret = Secret(ciphertext: CiphertextRef(id: UUID()), preview: preview, reason: .apiKey)
        let item = ClipItem(id: UUID(), kind: .text, createdAt: Date(), sourceApp: nil,
                            sensitivity: .detectedSecret(reason: .apiKey), payload: .secret(secret), contentHash: "h")

        let rows = ClipRow.rows(from: [item])
        #expect(rows.count == 1)
        #expect(rows[0].isSecret)
        #expect(rows[0].displayText == preview.masked)
        #expect(rows[0].secretContext == "15 chars · API key")
        #expect(!rows[0].displayText.contains("VerySecretValue"))
    }

    @Test("Generate then use stores the password as a secret in history")
    func generateAndUse() async throws {
        let engine = try makeEngine()
        let vm = ClipboardViewModel(engine: engine)

        await vm.generate(.characters(CharacterPolicy(length: 24)))
        #expect(vm.lastGenerated != nil)

        await vm.useGenerated()
        await vm.refresh()

        #expect(vm.rows.contains { $0.isSecret })
    }
}
