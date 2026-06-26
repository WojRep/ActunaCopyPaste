import Foundation
import Testing
@testable import ActunaCopyPasteCore

@Suite("ClipboardHistory")
struct ClipboardHistoryTests {

    private func item(
        hash: String,
        text: String,
        at seconds: TimeInterval,
        pinned: Bool = false,
        sensitivity: SensitivityClassification = .normal
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(timeIntervalSince1970: seconds),
            sourceApp: nil,
            pinned: pinned,
            sensitivity: sensitivity,
            payload: .plain(text),
            contentHash: hash
        )
    }

    @Test("Newest item appears first")
    func ordering() {
        var history = ClipboardHistory()
        history.add(item(hash: "a", text: "first", at: 1))
        history.add(item(hash: "b", text: "second", at: 2))
        #expect(history.count == 2)
        #expect(history.items.first?.contentHash == "b")
    }

    @Test("Re-adding identical content de-duplicates and refreshes to front")
    func dedup() {
        var history = ClipboardHistory()
        history.add(item(hash: "a", text: "x", at: 1))
        history.add(item(hash: "b", text: "y", at: 2))
        history.add(item(hash: "a", text: "x", at: 3)) // duplicate of "a", newer
        #expect(history.count == 2)
        #expect(history.items.first?.contentHash == "a")
    }

    @Test("De-duplication preserves the existing pin state")
    func dedupKeepsPin() {
        var history = ClipboardHistory()
        let a = item(hash: "a", text: "x", at: 1)
        history.add(a)
        history.pin(a.id)
        history.add(item(hash: "b", text: "y", at: 2))
        // Re-add "a" as an unpinned new capture
        history.add(item(hash: "a", text: "x", at: 3))
        let refreshed = history.items.first { $0.contentHash == "a" }
        #expect(refreshed?.pinned == true)
    }

    @Test("Pinned items float above unpinned")
    func pinFloats() {
        var history = ClipboardHistory()
        let a = item(hash: "a", text: "x", at: 1)
        history.add(a)
        history.add(item(hash: "b", text: "y", at: 2))
        history.add(item(hash: "c", text: "z", at: 3))
        history.pin(a.id)
        #expect(history.items.first?.contentHash == "a")
        #expect(history.items.first?.pinned == true)
    }

    @Test("Capacity evicts the oldest unpinned item")
    func eviction() {
        var history = ClipboardHistory(capacity: 2)
        history.add(item(hash: "a", text: "x", at: 1))
        history.add(item(hash: "b", text: "y", at: 2))
        history.add(item(hash: "c", text: "z", at: 3))
        #expect(history.count == 2)
        #expect(history.items.map(\.contentHash) == ["c", "b"])
    }

    @Test("Pinned items are never evicted")
    func pinnedSurvivesEviction() {
        var history = ClipboardHistory(capacity: 1)
        let a = item(hash: "a", text: "x", at: 1)
        history.add(a)
        history.pin(a.id)
        history.add(item(hash: "b", text: "y", at: 2))
        history.add(item(hash: "c", text: "z", at: 3))
        #expect(history.count == 2) // pinned "a" + newest unpinned "c"
        let hashes = Set(history.items.map(\.contentHash))
        #expect(hashes == ["a", "c"])
    }

    @Test("Transient items are discarded, not stored")
    func transientDiscarded() {
        var history = ClipboardHistory()
        history.add(item(hash: "t", text: "secret-flash", at: 1, sensitivity: .transient))
        #expect(history.count == 0)
    }

    @Test("Search matches normal text but never secret plaintext")
    func search() {
        var history = ClipboardHistory()
        history.add(item(hash: "a", text: "hello world", at: 1))

        let secret = Secret(
            ciphertext: CiphertextRef(id: UUID()),
            preview: MaskedPreview.make(from: "p4ssw0rd-world", context: "password"),
            reason: .highEntropy
        )
        let secretItem = ClipItem(
            id: UUID(), kind: .text, createdAt: Date(timeIntervalSince1970: 2),
            sourceApp: nil, sensitivity: .detectedSecret(reason: .highEntropy),
            payload: .secret(secret), contentHash: "s"
        )
        history.add(secretItem)

        let results = history.search("world")
        #expect(results.count == 1)
        #expect(results.first?.contentHash == "a")
    }

    @Test("Clear unpinned keeps favorites")
    func clearUnpinned() {
        var history = ClipboardHistory()
        let a = item(hash: "a", text: "keep", at: 1)
        history.add(a)
        history.pin(a.id)
        history.add(item(hash: "b", text: "drop", at: 2))
        history.clearUnpinned()
        #expect(history.items.map(\.contentHash) == ["a"])
    }
}
