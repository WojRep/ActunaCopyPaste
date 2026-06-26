import Foundation
@testable import ActunaCopyPasteCore

/// In-memory `SecretsVaultPort` for tests, implemented as an `actor` — the native
/// Swift concurrency primitive for safe shared mutable state (no locks).
///
/// Models the production policy: a secret pastes without a prompt only into a
/// positively-detected secure field; any other target degrades to a biometric
/// gate, simulated here by `biometricsWillSucceed`.
actor FakeSecretsVault: SecretsVaultPort {
    private var plaintexts: [UUID: String] = [:]
    private var biometricsWillSucceed: Bool

    init(biometricsWillSucceed: Bool = true) {
        self.biometricsWillSucceed = biometricsWillSucceed
    }

    func setBiometrics(_ succeed: Bool) { biometricsWillSucceed = succeed }

    func store(plaintext: String, context: String, reason: SecretReason?) async throws -> Secret {
        let id = UUID()
        plaintexts[id] = plaintext
        let preview = MaskedPreview.make(from: plaintext, context: context)
        return Secret(ciphertext: CiphertextRef(id: id), preview: preview, reason: reason)
    }

    func reveal(_ ref: CiphertextRef) async throws -> String {
        guard biometricsWillSucceed else { throw SecretsVaultError.authenticationFailed }
        guard let value = plaintexts[ref.id] else { throw SecretsVaultError.notFound }
        return value
    }

    func decryptForPaste(_ ref: CiphertextRef, target: FocusedFieldInfo) async throws -> String {
        if target.isSecureField != true {
            // Degrade to Touch ID for non-secure / unknown targets.
            guard biometricsWillSucceed else { throw SecretsVaultError.authenticationFailed }
        }
        guard let value = plaintexts[ref.id] else { throw SecretsVaultError.notFound }
        return value
    }

    func purge(_ ref: CiphertextRef) async throws {
        plaintexts[ref.id] = nil
    }
}
