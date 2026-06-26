import Foundation
import ActunaCopyPastePlatform

/// In-memory `KeyBlobStore` for tests. A class (the provisioner holds it by
/// reference so saves are observable) guarded by a lock for `Sendable` safety.
final class FakeKeyBlobStore: KeyBlobStore, @unchecked Sendable {
    private let lock = NSLock()
    private var blob: Data?
    private(set) var saveCount = 0
    private(set) var deleteCount = 0

    init(blob: Data? = nil) { self.blob = blob }

    func loadBlob() throws -> Data? { lock.withLock { blob } }
    func saveBlob(_ data: Data) throws { lock.withLock { blob = data; saveCount += 1 } }
    func deleteBlob() throws { lock.withLock { blob = nil; deleteCount += 1 } }
}
