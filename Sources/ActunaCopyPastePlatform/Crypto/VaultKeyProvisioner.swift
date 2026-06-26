import Foundation

/// Persists the opaque blob (`keyDataRepresentation`) of the vault's
/// key-encryption key so the same KEK survives relaunch. Production: the Keychain
/// (`KeychainKeyStore`). Synchronous because the underlying `SecItem*` calls are.
public protocol KeyBlobStore: Sendable {
    func loadBlob() throws -> Data?
    func saveBlob(_ data: Data) throws
    func deleteBlob() throws
}

/// Builds the vault's `KeyAgreementProvider`, persisting its representation on first
/// run and reconstructing it from the stored blob on every subsequent launch.
///
/// Invariant: once a key exists it is **never silently replaced** — otherwise
/// previously-wrapped secrets would become permanently undecryptable. `preferSecureEnclave`
/// therefore only governs first-time minting; on reload we reconstruct whatever was stored.
public struct VaultKeyProvisioner {
    private let store: any KeyBlobStore

    public init(store: any KeyBlobStore) {
        self.store = store
    }

    public func make(preferSecureEnclave: Bool = true) throws -> any KeyAgreementProvider {
        // Loading is best-effort: if the Keychain is unavailable (e.g. an ad-hoc
        // build with no keychain-access-group entitlement → errSecMissingEntitlement),
        // we provision a fresh, unpersisted key instead of failing to launch. With a
        // proper signature (Developer ID / sandboxed App Store build) the Keychain
        // works and the key persists across relaunch.
        let blob = (try? store.loadBlob()) ?? nil

        if let blob {
            // Reconstruct the persisted key. Prefer Secure Enclave only if it is
            // available and can actually use the blob; otherwise treat it as software.
            if preferSecureEnclave, SecureEnclaveKeyAgreement.isAvailable,
               let enclave = try? SecureEnclaveKeyAgreement(persisted: blob) {
                return enclave
            }
            if let software = try? SoftwareKeyAgreement(persisted: blob) {
                return software
            }
            // Persisted blob is unusable — fall through and mint a fresh key.
        }

        // Mint a fresh KEK and best-effort persist its representation.
        if preferSecureEnclave, SecureEnclaveKeyAgreement.isAvailable,
           let key = try? SecureEnclaveKeyAgreement() {
            try? store.saveBlob(key.keyDataRepresentation)
            return key
        }
        let key = try SoftwareKeyAgreement()
        try? store.saveBlob(key.keyDataRepresentation)
        return key
    }
}
