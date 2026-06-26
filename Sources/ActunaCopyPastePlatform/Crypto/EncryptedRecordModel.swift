import Foundation
import SwiftData
import ActunaCopyPasteCore

/// SwiftData persistence model for one encrypted secret. Flat columns
/// (CloudKit-ready: no `@Attribute(.unique)`, every property optional or
/// defaulted) mapped to/from the platform `EncryptedRecord`. Persists only the
/// envelope — ephemeral public key, ECDH-wrapped data key, and the sealed payload
/// — never plaintext and never the unwrapped data key.
@Model
final class EncryptedRecordModel {
    var id: UUID = UUID()
    var ephemeralPublicKey: Data = Data()
    var wrappedDataKey: Data = Data()
    var payload: Data = Data()
    var context: String = ""
    var reasonRaw: String?

    init(id: UUID, record: EncryptedRecord) {
        self.id = id
        update(from: record)
    }

    /// Overwrites the envelope columns (id is the identity key and stays put).
    func update(from record: EncryptedRecord) {
        ephemeralPublicKey = record.ephemeralPublicKey
        wrappedDataKey = record.wrappedDataKey
        payload = record.payload
        context = record.context
        reasonRaw = record.reason?.rawValue
    }

    func toRecord() -> EncryptedRecord {
        EncryptedRecord(
            ephemeralPublicKey: ephemeralPublicKey,
            wrappedDataKey: wrappedDataKey,
            payload: payload,
            context: context,
            reason: reasonRaw.flatMap(SecretReason.init(rawValue:))
        )
    }
}
