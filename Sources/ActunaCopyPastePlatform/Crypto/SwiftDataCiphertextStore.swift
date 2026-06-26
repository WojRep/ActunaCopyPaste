import Foundation
import SwiftData
import ActunaCopyPasteCore

/// Native `CiphertextStore` backed by SwiftData. An `actor` isolates the
/// non-Sendable `ModelContext`; only Sendable values cross the boundary.
///
/// In production this shares one persistence stack with the history store: build a
/// single `ModelContainer` registering both `ClipRecord.self` and
/// `EncryptedRecordModel.self`, then hand it to both `SwiftDataHistoryStore` and
/// this store. The factories below are for tests/previews and standalone use.
public actor SwiftDataCiphertextStore: CiphertextStore {
    private let container: ModelContainer
    private let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    /// In-memory store for tests/previews.
    public static func inMemory() throws -> SwiftDataCiphertextStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: EncryptedRecordModel.self, configurations: config)
        return SwiftDataCiphertextStore(container: container)
    }

    /// On-disk store at `url` (secrets are device-local — never CloudKit-synced).
    public static func onDisk(url: URL) throws -> SwiftDataCiphertextStore {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: EncryptedRecordModel.self, configurations: config)
        return SwiftDataCiphertextStore(container: container)
    }

    public func put(_ id: UUID, _ record: EncryptedRecord) async throws {
        let descriptor = FetchDescriptor<EncryptedRecordModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            context.insert(EncryptedRecordModel(id: id, record: record))
        }
        try context.save()
    }

    public func get(_ id: UUID) async throws -> EncryptedRecord? {
        let descriptor = FetchDescriptor<EncryptedRecordModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first?.toRecord()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<EncryptedRecordModel>(predicate: #Predicate { $0.id == id })
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
