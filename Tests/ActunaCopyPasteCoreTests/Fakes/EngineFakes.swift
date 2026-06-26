import Foundation
@testable import ActunaCopyPasteCore

/// In-memory `HistoryStorePort` (actor).
actor InMemoryHistoryStore: HistoryStorePort {
    private var items: [UUID: ClipItem] = [:]

    func load() async throws -> [ClipItem] {
        Array(items.values).sorted { $0.createdAt > $1.createdAt }
    }
    func upsert(_ item: ClipItem) async throws { items[item.id] = item }
    func remove(id: UUID) async throws { items[id] = nil }
    func replaceAll(_ newItems: [ClipItem]) async throws {
        items = Dictionary(newItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    func storedCount() -> Int { items.count }
}

/// Records writes to the system pasteboard (write-only path).
actor SpyClipboardWriter: ClipboardWriterPort {
    private(set) var writes: [(text: String, autoClear: TimeInterval?)] = []
    func write(_ text: String, autoClearAfter seconds: TimeInterval?) async throws {
        writes.append((text, seconds))
    }
}

/// Records paste (write + ⌘V) actions.
actor SpyPaster: PastePort {
    private(set) var pastes: [(text: String, autoClear: TimeInterval?)] = []
    func paste(text: String, autoClearAfter seconds: TimeInterval?) async throws {
        pastes.append((text, seconds))
    }
}
