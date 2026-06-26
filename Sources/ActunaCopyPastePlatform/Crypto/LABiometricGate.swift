import Foundation
import LocalAuthentication
import ActunaCopyPasteCore

/// Biometric gate backed by LocalAuthentication (Touch ID).
///
/// A fresh `LAContext` is created per call (correct, if conservative; session
/// reuse via `touchIDAuthenticationAllowableReuseDuration` needs a shared,
/// MainActor-confined context and is a later optimization). There is no async
/// overload of `evaluatePolicy`, so it is bridged with a continuation.
public struct LABiometricGate: BiometricGate {
    public init() {}

    public func authenticate(reason: String) async throws {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            throw SecretsVaultError.authenticationUnavailable
        }

        let success: Bool
        do {
            success = try await withCheckedThrowingContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ok)
                    }
                }
            }
        } catch {
            throw SecretsVaultError.authenticationFailed
        }
        guard success else { throw SecretsVaultError.authenticationFailed }
    }
}
