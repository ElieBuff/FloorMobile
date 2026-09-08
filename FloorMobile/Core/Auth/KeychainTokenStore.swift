//
//  KeychainTokenStore.swift
//  FloorMobile
//

import Foundation
import Security

/// Stores the whole `TokenSet` as a single JSON-encoded Keychain item, so a
/// token rotation is persisted atomically (all three tokens or nothing).
///
/// Accessibility is `AfterFirstUnlockThisDeviceOnly`: readable during
/// background refreshes once the device has been unlocked, never migrated
/// to another device.
final actor KeychainTokenStore: TokenStore {
    private let service: String
    private let account = "auth.tokens"

    init(service: String = Bundle.main.bundleIdentifier ?? "FloorMobile") {
        self.service = service
    }

    func save(_ tokens: TokenSet) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(tokens)
        } catch {
            throw AppError.storage(underlying: error)
        }

        var status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var attributes = baseQuery
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw AppError.storage(underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    func load() async -> TokenSet? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        // A corrupted item is treated as "signed out" rather than a fatal error.
        return try? JSONDecoder().decode(TokenSet.self, from: data)
    }

    func clear() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.storage(underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
