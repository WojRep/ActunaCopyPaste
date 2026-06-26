import Foundation
import Testing
@testable import ActunaCopyPasteCore

/// Contract tests for the secrets policy: a secret pastes without a prompt only
/// into a positively-detected secure (password) field; any other target degrades
/// to a biometric gate. The production Secure-Enclave adapter satisfies the same
/// contract (see EnvelopeVaultTests in the platform tests).
@Suite("SecretsVault policy")
struct SecretsVaultPolicyTests {

    @Test("Paste into a secure field needs no biometrics")
    func pasteIntoSecureField() async throws {
        let vault = FakeSecretsVault(biometricsWillSucceed: false) // biometrics would fail…
        let secret = try await vault.store(plaintext: "hunter2!", context: "password", reason: nil)
        let target = FocusedFieldInfo(isSecureField: true, appBundleID: "com.apple.Safari")
        // …yet a secure field still pastes, because no prompt is required.
        #expect(try await vault.decryptForPaste(secret.ciphertext, target: target) == "hunter2!")
    }

    @Test("Paste into a non-secure field degrades to Touch ID and succeeds when approved")
    func nonSecureWithBiometrics() async throws {
        let vault = FakeSecretsVault(biometricsWillSucceed: true)
        let secret = try await vault.store(plaintext: "hunter2!", context: "password", reason: nil)
        let target = FocusedFieldInfo(isSecureField: false, appBundleID: "com.apple.TextEdit")
        #expect(try await vault.decryptForPaste(secret.ciphertext, target: target) == "hunter2!")
    }

    @Test("Paste into a non-secure field is refused when biometrics fail")
    func nonSecureWithoutBiometrics() async throws {
        let vault = FakeSecretsVault(biometricsWillSucceed: false)
        let secret = try await vault.store(plaintext: "hunter2!", context: "password", reason: nil)
        let target = FocusedFieldInfo(isSecureField: false, appBundleID: "com.apple.TextEdit")
        await #expect(throws: SecretsVaultError.authenticationFailed) {
            try await vault.decryptForPaste(secret.ciphertext, target: target)
        }
    }

    @Test("Reveal requires biometrics")
    func reveal() async throws {
        let ok = FakeSecretsVault(biometricsWillSucceed: true)
        let secret = try await ok.store(plaintext: "hunter2!", context: "password", reason: nil)
        #expect(try await ok.reveal(secret.ciphertext) == "hunter2!")

        let denied = FakeSecretsVault(biometricsWillSucceed: false)
        let secret2 = try await denied.store(plaintext: "x", context: "password", reason: nil)
        await #expect(throws: SecretsVaultError.authenticationFailed) {
            try await denied.reveal(secret2.ciphertext)
        }
    }
}
