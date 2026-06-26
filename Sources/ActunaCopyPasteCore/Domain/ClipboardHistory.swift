import Foundation

/// Aggregate root for the clipboard history.
///
/// Invariants:
/// - Items are ordered pinned-first, then by recency (newest first).
/// - `contentHash` is unique: re-adding identical content refreshes the existing
///   entry (moves it to the front, keeps its pin state) instead of duplicating.
/// - Capacity bounds only *unpinned* items; pinned items are never evicted.
public struct ClipboardHistory: Sendable, Equatable {
    public let capacity: Int
    private var storage: [ClipItem]

    public init(capacity: Int = 200) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        self.storage = []
    }

    /// Current items in display order (pinned first, then newest first).
    public var items: [ClipItem] { storage }

    public var count: Int { storage.count }

    /// Adds content, de-duplicating by `contentHash`. Transient items are dropped.
    public mutating func add(_ item: ClipItem) {
        if item.sensitivity.shouldDiscard { return }

        if let existingIndex = storage.firstIndex(where: { $0.contentHash == item.contentHash }) {
            // Refresh: keep prior pin state, adopt the newer item otherwise.
            var refreshed = item
            refreshed.pinned = storage[existingIndex].pinned
            storage.remove(at: existingIndex)
            storage.append(refreshed)
        } else {
            storage.append(item)
        }
        reorder()
        evictIfNeeded()
    }

    public mutating func pin(_ id: UUID) { setPinned(id, true) }
    public mutating func unpin(_ id: UUID) { setPinned(id, false) }

    public mutating func remove(_ id: UUID) {
        storage.removeAll { $0.id == id }
    }

    /// Removes every non-pinned item (e.g. "clear history" while keeping favorites).
    public mutating func clearUnpinned() {
        storage.removeAll { !$0.pinned }
    }

    public func item(withID id: UUID) -> ClipItem? {
        storage.first { $0.id == id }
    }

    /// Case-insensitive substring search over searchable (non-secret) text,
    /// preserving display order.
    public func search(_ query: String) -> [ClipItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return storage }
        return storage.filter {
            ($0.payload.searchableText?.lowercased().contains(needle)) ?? false
        }
    }

    // MARK: - Private

    private mutating func setPinned(_ id: UUID, _ pinned: Bool) {
        guard let index = storage.firstIndex(where: { $0.id == id }) else { return }
        storage[index].pinned = pinned
        reorder()
    }

    /// Pinned first; within each group, newest `createdAt` first. Ties broken by
    /// `id` for a deterministic, stable order.
    private mutating func reorder() {
        storage.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    /// Drops oldest unpinned items so the unpinned count stays within capacity.
    private mutating func evictIfNeeded() {
        var unpinnedCount = storage.reduce(0) { $0 + ($1.pinned ? 0 : 1) }
        guard unpinnedCount > capacity else { return }
        // Remove from the tail (oldest), skipping pinned items.
        var index = storage.count - 1
        while index >= 0 && unpinnedCount > capacity {
            if !storage[index].pinned {
                storage.remove(at: index)
                unpinnedCount -= 1
            }
            index -= 1
        }
    }
}
