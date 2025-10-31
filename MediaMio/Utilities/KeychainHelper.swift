//
//  KeychainHelper.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case invalidData
}

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    // MARK: - Save
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key)
    }

    // MARK: - Retrieve
    func retrieve(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Delete
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Clear All
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}

// MARK: - Convenience Methods for Auth
extension KeychainHelper {
    func saveCredentials(serverURL: String, username: String, accessToken: String, userId: String) throws {
        try save(serverURL, for: Constants.Keychain.serverURLKey)
        try save(username, for: Constants.Keychain.usernameKey)
        try save(accessToken, for: Constants.Keychain.accessTokenKey)
        try save(userId, for: Constants.Keychain.userIdKey)
    }

    func retrieveCredentials() -> (serverURL: String, username: String, accessToken: String, userId: String)? {
        guard
            let serverURL = try? retrieveString(for: Constants.Keychain.serverURLKey),
            let username = try? retrieveString(for: Constants.Keychain.usernameKey),
            let accessToken = try? retrieveString(for: Constants.Keychain.accessTokenKey),
            let userId = try? retrieveString(for: Constants.Keychain.userIdKey)
        else {
            return nil
        }

        return (serverURL, username, accessToken, userId)
    }

    func clearCredentials() {
        try? delete(for: Constants.Keychain.serverURLKey)
        try? delete(for: Constants.Keychain.usernameKey)
        try? delete(for: Constants.Keychain.accessTokenKey)
        try? delete(for: Constants.Keychain.userIdKey)
    }
}
