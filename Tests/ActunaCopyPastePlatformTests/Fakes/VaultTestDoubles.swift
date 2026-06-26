import Foundation
import ActunaCopyPasteCore
import ActunaCopyPastePlatform

/// In-memory `CiphertextStore` (actor — native concurrency, no locks).
actor InMemoryCiphertextStore: CiphertextStore {
    private var records: [UUID: EncryptedRecord] = [:]

    func put(_ id: UUID, _ record: EncryptedRecord) async throws { records[id] = record }
    func get(_ id: UUID) async throws -> EncryptedRecord? { records[id] }
    func delete(_ id: UUID) async throws { records[id] = nil }

    /// Test-only inspection of what was actually persisted.
    func snapshot() -> [UUID: EncryptedRecord] { records }
}

/// Biometric gate that always approves.
struct AllowingGate: BiometricGate {
    func authenticate(reason: String) async throws {}
}

/// Biometric gate that always denies.
struct DenyingGate: BiometricGate {
    func authenticate(reason: String) async throws {
        throw SecretsVaultError.authenticationFailed
    }
}
