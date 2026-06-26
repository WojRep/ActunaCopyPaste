import Foundation
import SwiftData
import ActunaCopyPasteCore

/// Native `HistoryStorePort` backed by SwiftData (the modern Swift 6 facade over
/// Core Data). An `actor` isolates the non-Sendable `ModelContext`; only Sendable
/// domain values cross the boundary. CloudKit sync is enabled by constructing the
/// store with a CloudKit-configured `ModelContainer`.
public actor SwiftDataHistoryStore: HistoryStorePort {
    private let container: ModelContainer
    private let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    /// In-memory store for tests/previews.
    public static func inMemory() throws -> SwiftDataHistoryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ClipRecord.self, configurations: config)
        return SwiftDataHistoryStore(container: container)
    }

    /// On-disk store at `url`. Pass `cloudKitDatabase: .private("iCloud.…")` via a
    /// custom `ModelConfiguration` to the `init(container:)` for sync.
    public static func onDisk(url: URL) throws -> SwiftDataHistoryStore {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: ClipRecord.self, configurations: config)
        return SwiftDataHistoryStore(container: container)
    }

    public func load() async throws -> [ClipItem] {
        let descriptor = FetchDescriptor<ClipRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    public func upsert(_ item: ClipItem) async throws {
        let targetID = item.id
        let descriptor = FetchDescriptor<ClipRecord>(predicate: #Predicate { $0.id == targetID })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            context.insert(ClipRecord(item: item))
        }
        try context.save()
    }

    public func remove(id: UUID) async throws {
        let descriptor = FetchDescriptor<ClipRecord>(predicate: #Predicate { $0.id == id })
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }

    public func replaceAll(_ items: [ClipItem]) async throws {
        try context.delete(model: ClipRecord.self)
        for item in items {
            context.insert(ClipRecord(item: item))
        }
        try context.save()
    }
}
