import Foundation
import SwiftData

/// Builds the shared SwiftData persistence stack. One `ModelContainer` registers
/// BOTH the history model (`ClipRecord`) and the secrets envelope model
/// (`EncryptedRecordModel`), then backs both stores — a single on-disk file, one
/// stack. The `@Model` types stay internal to this module; callers receive ready
/// `HistoryStorePort` / `CiphertextStore` adapters.
public enum ActunaPersistence {

    /// History + ciphertext stores sharing one on-disk container at `url`.
    /// Secrets are device-local — this container is never CloudKit-configured.
    public static func makeStores(at url: URL) throws
    -> (history: SwiftDataHistoryStore, ciphertext: SwiftDataCiphertextStore) {
        let container = try ModelContainer(
            for: ClipRecord.self, EncryptedRecordModel.self,
            configurations: ModelConfiguration(url: url)
        )
        return (SwiftDataHistoryStore(container: container),
                SwiftDataCiphertextStore(container: container))
    }

    /// In-memory variant for tests/previews.
    public static func makeInMemoryStores() throws
    -> (history: SwiftDataHistoryStore, ciphertext: SwiftDataCiphertextStore) {
        let container = try ModelContainer(
            for: ClipRecord.self, EncryptedRecordModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (SwiftDataHistoryStore(container: container),
                SwiftDataCiphertextStore(container: container))
    }
}
