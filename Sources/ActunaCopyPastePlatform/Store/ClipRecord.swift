import Foundation
import SwiftData
import ActunaCopyPasteCore

/// SwiftData persistence model for a clip. Flat columns (CloudKit-ready: no
/// `@Attribute(.unique)`, every property optional or defaulted) mapped to/from the
/// domain `ClipItem`. Secrets persist ONLY their masked preview + ciphertext
/// reference — never plaintext (the ciphertext itself lives in the secrets vault).
@Model
final class ClipRecord {
    var id: UUID = UUID()
    var kindRaw: String = ClipKind.text.rawValue
    var createdAt: Date = Date.distantPast
    var sourceApp: String?
    var pinned: Bool = false
    var contentHash: String = ""

    // Sensitivity: normal | concealed | transient | detected
    var sensitivityKind: String = "normal"
    var secretReasonRaw: String?

    // Payload: plain | resource | secret
    var payloadKind: String = "plain"
    var plainText: String?
    var resourceReference: String?
    var resourceLabel: String?

    // Secret payload — masked preview only.
    var ciphertextID: UUID?
    var maskedString: String?
    var maskedVisiblePrefix: String?
    var maskedVisibleSuffix: String?
    var maskedHiddenCount: Int?
    var maskedContext: String?

    init(item: ClipItem) {
        update(from: item)
    }

    func update(from item: ClipItem) {
        id = item.id
        kindRaw = item.kind.rawValue
        createdAt = item.createdAt
        sourceApp = item.sourceApp
        pinned = item.pinned
        contentHash = item.contentHash

        switch item.sensitivity {
        case .normal:
            sensitivityKind = "normal"; secretReasonRaw = nil
        case .concealedByMarker:
            sensitivityKind = "concealed"; secretReasonRaw = nil
        case .transient:
            sensitivityKind = "transient"; secretReasonRaw = nil
        case .detectedSecret(let reason):
            sensitivityKind = "detected"; secretReasonRaw = reason.rawValue
        }

        // Reset payload columns, then set the active variant.
        plainText = nil; resourceReference = nil; resourceLabel = nil
        ciphertextID = nil; maskedString = nil; maskedVisiblePrefix = nil
        maskedVisibleSuffix = nil; maskedHiddenCount = nil; maskedContext = nil

        switch item.payload {
        case .plain(let text):
            payloadKind = "plain"; plainText = text
        case .resource(let reference, let label):
            payloadKind = "resource"; resourceReference = reference; resourceLabel = label
        case .secret(let secret):
            payloadKind = "secret"
            ciphertextID = secret.ciphertext.id
            maskedString = secret.preview.masked
            maskedVisiblePrefix = secret.preview.visiblePrefix
            maskedVisibleSuffix = secret.preview.visibleSuffix
            maskedHiddenCount = secret.preview.hiddenCount
            maskedContext = secret.preview.context
        }
    }

    /// Rebuilds the domain entity. Returns nil if the row is inconsistent.
    func toDomain() -> ClipItem? {
        guard let kind = ClipKind(rawValue: kindRaw) else { return nil }

        let sensitivity: SensitivityClassification
        switch sensitivityKind {
        case "normal": sensitivity = .normal
        case "concealed": sensitivity = .concealedByMarker
        case "transient": sensitivity = .transient
        case "detected":
            guard let raw = secretReasonRaw, let reason = SecretReason(rawValue: raw) else { return nil }
            sensitivity = .detectedSecret(reason: reason)
        default: return nil
        }

        let payload: ClipPayload
        switch payloadKind {
        case "plain":
            payload = .plain(plainText ?? "")
        case "resource":
            payload = .resource(reference: resourceReference ?? "", label: resourceLabel ?? "")
        case "secret":
            guard let ciphertextID, let maskedString, let hidden = maskedHiddenCount else { return nil }
            let reason: SecretReason? = secretReasonRaw.flatMap(SecretReason.init(rawValue:))
            let preview = MaskedPreview(
                masked: maskedString,
                visiblePrefix: maskedVisiblePrefix ?? "",
                visibleSuffix: maskedVisibleSuffix ?? "",
                hiddenCount: hidden,
                context: maskedContext ?? ""
            )
            payload = .secret(Secret(ciphertext: CiphertextRef(id: ciphertextID), preview: preview, reason: reason))
        default:
            return nil
        }

        return ClipItem(
            id: id, kind: kind, createdAt: createdAt, sourceApp: sourceApp,
            pinned: pinned, sensitivity: sensitivity, payload: payload, contentHash: contentHash
        )
    }
}
