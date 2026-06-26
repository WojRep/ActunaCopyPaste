import Foundation

/// What kind of content a clip holds.
public enum ClipKind: String, Sendable, Equatable, CaseIterable {
    case text
    case code
    case image
    case file
}

/// Opaque handle to ciphertext held by the secrets vault. The domain never sees
/// plaintext of a secret — only this reference plus the masked preview.
public struct CiphertextRef: Sendable, Equatable, Hashable {
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

/// A sensitive value: stored as ciphertext, shown only as a masked preview.
/// Plaintext is reachable solely through `SecretsVaultPort` under policy.
public struct Secret: Sendable, Equatable {
    public let ciphertext: CiphertextRef
    public let preview: MaskedPreview
    /// Why it was treated as a secret (nil when flagged purely by marker).
    public let reason: SecretReason?

    public init(ciphertext: CiphertextRef, preview: MaskedPreview, reason: SecretReason?) {
        self.ciphertext = ciphertext
        self.preview = preview
        self.reason = reason
    }
}

/// The payload of a clip — either ordinary content or a reference to a secret.
public enum ClipPayload: Sendable, Equatable {
    /// Display/searchable text for ordinary text or code clips.
    case plain(String)
    /// On-disk (encrypted) resource reference for images/files, with a label.
    case resource(reference: String, label: String)
    /// A sensitive value; only its masked preview is ever shown.
    case secret(Secret)

    /// Text safe to display in the history list (masked for secrets).
    public var displayText: String {
        switch self {
        case .plain(let text): return text
        case .resource(_, let label): return label
        case .secret(let secret): return secret.preview.masked
        }
    }

    /// Text safe to index for search. Secrets are never indexed in plaintext.
    public var searchableText: String? {
        switch self {
        case .plain(let text): return text
        case .resource(_, let label): return label
        case .secret: return nil
        }
    }
}

/// A single entry in the clipboard history (domain entity, identified by `id`).
public struct ClipItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: ClipKind
    public let createdAt: Date
    public let sourceApp: String?
    public var pinned: Bool
    public let sensitivity: SensitivityClassification
    public let payload: ClipPayload
    /// Stable hash of the original content, used for de-duplication without
    /// retaining plaintext of secrets.
    public let contentHash: String

    public init(
        id: UUID,
        kind: ClipKind,
        createdAt: Date,
        sourceApp: String?,
        pinned: Bool = false,
        sensitivity: SensitivityClassification,
        payload: ClipPayload,
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.pinned = pinned
        self.sensitivity = sensitivity
        self.payload = payload
        self.contentHash = contentHash
    }

    public var isSensitive: Bool { sensitivity.isSensitive }
}
