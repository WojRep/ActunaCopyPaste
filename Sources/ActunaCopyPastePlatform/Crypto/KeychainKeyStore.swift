import Foundation
import Security

/// `KeyBlobStore` backed by the macOS data-protection Keychain (Security framework).
///
/// The KEK blob is stored as a `kSecClassGenericPassword` item, accessible
/// `WhenUnlockedThisDeviceOnly` so it never migrates off this device (the KEK is
/// device-bound and pairs with the local Secure Enclave). No biometric
/// `SecAccessControl` is attached to the key itself — Touch ID is enforced by
/// `EnvelopeVault`'s gate, not the key, so pasting into a secure field stays promptless.
public struct KeychainKeyStore: KeyBlobStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case unexpectedData
    }

    private let service: String
    private let account: String

    public init(service: String = "pl.actuna.copypaste.kek", account: String = "v1") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Use the modern data-protection keychain: access is governed by the
            // app's signature/entitlements, NOT the interactive "allow/always allow"
            // SecurityAgent dialog the legacy keychain shows (which would block an
            // ad-hoc-signed app on every re-signed launch).
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    public func loadBlob() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func saveBlob(_ data: Data) throws {
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func deleteBlob() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
