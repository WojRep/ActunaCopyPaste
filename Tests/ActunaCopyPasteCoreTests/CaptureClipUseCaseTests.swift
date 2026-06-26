import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("CaptureClipUseCase")
struct CaptureClipUseCaseTests {

    private func makeSUT() -> (CaptureClipUseCase, FakeSecretsVault) {
        let vault = FakeSecretsVault()
        let sut = CaptureClipUseCase(
            classifier: SensitivityClassifier(),
            vault: vault,
            hashing: FNV1aHashing()
        )
        return (sut, vault)
    }

    private func content(
        kind: ClipKind = .text,
        text: String? = nil,
        resource: String? = nil,
        label: String? = nil,
        markers: Set<PasteboardMarker> = []
    ) -> CapturedContent {
        CapturedContent(kind: kind, text: text, resourceReference: resource,
                        label: label, sourceApp: "com.example.app", markers: markers)
    }

    @Test("Ordinary text becomes a plain, non-sensitive clip")
    func plainText() async throws {
        let (sut, _) = makeSUT()
        let item = try await sut.capture(content(text: "hello world"),
                                         id: UUID(), now: Date(timeIntervalSince1970: 1))
        let item2 = try #require(item)
        #expect(item2.sensitivity == .normal)
        #expect(item2.payload == .plain("hello world"))
        #expect(item2.contentHash == FNV1aHashing().hash("hello world"))
    }

    @Test("Concealed-marked content is stored as an encrypted, masked secret")
    func concealedSecret() async throws {
        let (sut, vault) = makeSUT()
        let item = try await sut.capture(content(text: "S3cr3t-Passphrase!", markers: [.concealed]),
                                         id: UUID(), now: Date(timeIntervalSince1970: 1))
        let clip = try #require(item)
        #expect(clip.sensitivity == .concealedByMarker)
        guard case .secret(let secret) = clip.payload else {
            Issue.record("expected a secret payload"); return
        }
        #expect(secret.reason == nil)
        #expect(clip.payload.searchableText == nil)            // never indexed in plaintext
        #expect(clip.payload.displayText.contains("\u{2022}")) // shown masked
        // Plaintext is recoverable only through the vault.
        let revealed = try await vault.reveal(secret.ciphertext)
        #expect(revealed == "S3cr3t-Passphrase!")
    }

    @Test("A detected JWT is captured as a secret with the right reason and context")
    func detectedJWT() async throws {
        let (sut, _) = makeSUT()
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.abcDEF123_-xyz"
        let item = try await sut.capture(content(text: jwt), id: UUID(), now: Date(timeIntervalSince1970: 1))
        let clip = try #require(item)
        #expect(clip.sensitivity == .detectedSecret(reason: .jwt))
        guard case .secret(let secret) = clip.payload else {
            Issue.record("expected a secret payload"); return
        }
        #expect(secret.reason == .jwt)
        #expect(secret.preview.context.contains("JWT token"))
    }

    @Test("Transient content is dropped")
    func transient() async throws {
        let (sut, _) = makeSUT()
        let item = try await sut.capture(content(text: "flash", markers: [.transient]),
                                         id: UUID(), now: Date(timeIntervalSince1970: 1))
        #expect(item == nil)
    }

    @Test("Image content becomes a resource clip")
    func image() async throws {
        let (sut, _) = makeSUT()
        let item = try await sut.capture(
            content(kind: .image, resource: "/tmp/shot.png", label: "shot.png"),
            id: UUID(), now: Date(timeIntervalSince1970: 1)
        )
        let clip = try #require(item)
        #expect(clip.kind == .image)
        #expect(clip.payload == .resource(reference: "/tmp/shot.png", label: "shot.png"))
        #expect(clip.sensitivity == .normal)
    }

    @Test("Captured item flows into history; secrets stay unsearchable end-to-end")
    func endToEnd() async throws {
        let (sut, _) = makeSUT()
        var history = ClipboardHistory()

        if let normal = try await sut.capture(content(text: "project notes about world"),
                                              id: UUID(), now: Date(timeIntervalSince1970: 1)) {
            history.add(normal)
        }
        if let secret = try await sut.capture(content(text: "world-domination-key-9F3K2", markers: [.concealed]),
                                              id: UUID(), now: Date(timeIntervalSince1970: 2)) {
            history.add(secret)
        }

        #expect(history.count == 2)
        let results = history.search("world")
        #expect(results.count == 1) // only the plain note, never the secret
    }
}
