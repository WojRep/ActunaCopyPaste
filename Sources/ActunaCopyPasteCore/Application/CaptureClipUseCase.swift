import Foundation

/// Application service: turns raw captured pasteboard content into a `ClipItem`,
/// routing sensitive content through the secrets vault so plaintext is encrypted
/// and only a masked preview is retained.
///
/// Returns `nil` when the content must not be recorded (e.g. transient).
/// The caller owns the `ClipboardHistory` aggregate and adds the result to it.
public struct CaptureClipUseCase: Sendable {
    private let classifier: SensitivityClassifier
    private let vault: SecretsVaultPort
    private let hashing: ContentHashing

    public init(classifier: SensitivityClassifier, vault: SecretsVaultPort, hashing: ContentHashing) {
        self.classifier = classifier
        self.vault = vault
        self.hashing = hashing
    }

    public func capture(_ content: CapturedContent, id: UUID, now: Date) async throws -> ClipItem? {
        let classification = classifier.classify(markers: content.markers, content: content.text)
        if classification.shouldDiscard { return nil }

        let payload: ClipPayload
        if classification.isSensitive, let text = content.text, !text.isEmpty {
            payload = .secret(try await makeSecret(text: text, classification: classification))
        } else {
            payload = makePlainPayload(content)
        }

        let hashInput = content.text ?? content.resourceReference ?? content.label ?? ""
        return ClipItem(
            id: id,
            kind: content.kind,
            createdAt: now,
            sourceApp: content.sourceApp,
            sensitivity: classification,
            payload: payload,
            contentHash: hashing.hash(hashInput)
        )
    }

    private func makeSecret(text: String, classification: SensitivityClassification) async throws -> Secret {
        let reason: SecretReason? = {
            if case .detectedSecret(let r) = classification { return r }
            return nil
        }()
        let context = "\(text.count) chars · \(reason?.label ?? "concealed")"
        return try await vault.store(plaintext: text, context: context, reason: reason)
    }

    private func makePlainPayload(_ content: CapturedContent) -> ClipPayload {
        switch content.kind {
        case .image, .file:
            return .resource(reference: content.resourceReference ?? "", label: content.label ?? "")
        case .text, .code:
            return .plain(content.text ?? "")
        }
    }
}
