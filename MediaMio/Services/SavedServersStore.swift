//
//  SavedServersStore.swift
//  MediaMio
//
//  Tracks every (server, user) pair the TV has signed in to and lets the
//  server-entry screen show them as "pick up where you left off" tiles.
//  The list metadata (server URL, display name, user names, last-used
//  timestamps) lives in UserDefaults as a JSON blob; the actual access
//  tokens live in the Keychain, keyed per (serverURL, userId).
//
//  Constraint: this store is pure persistence. It never performs HTTP and
//  it never decides whether a stored token is still valid — callers do
//  that by asking `AuthenticationService` to restore the session.
//

import Combine
import Foundation

@MainActor
final class SavedServersStore: ObservableObject {

    @Published private(set) var servers: [SavedServer] = []

    private let defaults: UserDefaults
    private let keychain: KeychainHelper

    init(defaults: UserDefaults = .standard, keychain: KeychainHelper = .shared) {
        self.defaults = defaults
        self.keychain = keychain
        self.servers = Self.loadServers(from: defaults)
    }

    // MARK: - Reads

    /// Saved servers sorted most-recent-first for UI display.
    var sorted: [SavedServer] {
        servers.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    func token(for server: SavedServer, user: SavedUser) -> String? {
        keychain.token(serverURL: server.url, userId: user.id)
    }

    // MARK: - Writes

    /// Record a successful login. Updates an existing `(server, user)` entry
    /// in place or appends a new one; always bumps `lastUsedAt` so the most
    /// recent login floats to the top of the picker.
    func remember(
        serverURL: String,
        serverName: String,
        user: User,
        accessToken: String
    ) {
        let now = Date()
        try? keychain.saveToken(accessToken, serverURL: serverURL, userId: user.id)

        if let serverIndex = servers.firstIndex(where: { $0.url == serverURL }) {
            servers[serverIndex].name = serverName
            servers[serverIndex].lastUsedAt = now

            if let userIndex = servers[serverIndex].users.firstIndex(where: { $0.id == user.id }) {
                servers[serverIndex].users[userIndex].lastUsedAt = now
            } else {
                servers[serverIndex].users.append(
                    SavedUser(id: user.id, name: user.name, lastUsedAt: now)
                )
            }
        } else {
            servers.append(
                SavedServer(
                    url: serverURL,
                    name: serverName,
                    users: [SavedUser(id: user.id, name: user.name, lastUsedAt: now)],
                    lastUsedAt: now
                )
            )
        }

        persist()
    }

    /// Drop a single user from a server. If that empties the server, drop
    /// the server too. The token is wiped from Keychain either way.
    func forget(serverURL: String, userId: String) {
        keychain.deleteToken(serverURL: serverURL, userId: userId)

        guard let serverIndex = servers.firstIndex(where: { $0.url == serverURL }) else {
            return
        }
        servers[serverIndex].users.removeAll { $0.id == userId }
        if servers[serverIndex].users.isEmpty {
            servers.remove(at: serverIndex)
        }
        persist()
    }

    /// Drop an entire server and every user under it.
    func forgetServer(serverURL: String) {
        guard let serverIndex = servers.firstIndex(where: { $0.url == serverURL }) else {
            return
        }
        for user in servers[serverIndex].users {
            keychain.deleteToken(serverURL: serverURL, userId: user.id)
        }
        servers.remove(at: serverIndex)
        persist()
    }

    // MARK: - Migration
    //
    // `AuthenticationService` used to persist exactly one (server, user,
    // token) tuple in the Keychain's legacy single-blob slot. If a user
    // upgraded to this build with that slot populated, seed the saved-
    // servers list from it on first launch so they don't lose their
    // signed-in state — matches the same UX they had pre-upgrade.

    /// Returns true if a legacy single-blob credential was successfully
    /// migrated into the saved-servers store. Idempotent — does nothing if
    /// the store already contains that `(server, user)` pair.
    @discardableResult
    func migrateLegacySingleBlobIfNeeded() -> Bool {
        guard let credentials = keychain.retrieveCredentials() else {
            return false
        }
        let alreadyPresent = servers.contains { saved in
            saved.url == credentials.serverURL
                && saved.users.contains { $0.id == credentials.userId }
        }
        if alreadyPresent { return false }

        // Seed the server-display-name with the host, since the legacy
        // blob didn't record it. `AuthenticationService.restoreSession`
        // will overwrite it with the real server name on next connect.
        let fallbackName = URL(string: credentials.serverURL)?.host ?? credentials.serverURL
        let user = User(
            id: credentials.userId,
            name: credentials.username,
            serverId: "",
            hasPassword: true,
            hasConfiguredPassword: true
        )
        remember(
            serverURL: credentials.serverURL,
            serverName: fallbackName,
            user: user,
            accessToken: credentials.accessToken
        )
        return true
    }

    // MARK: - Persistence helpers

    private func persist() {
        do {
            let data = try JSONEncoder().encode(servers)
            defaults.set(data, forKey: Constants.UserDefaultsKeys.savedServers)
        } catch {
            print("⚠️ SavedServersStore: failed to encode servers: \(error)")
        }
    }

    private static func loadServers(from defaults: UserDefaults) -> [SavedServer] {
        guard let data = defaults.data(forKey: Constants.UserDefaultsKeys.savedServers) else {
            return []
        }
        do {
            return try JSONDecoder().decode([SavedServer].self, from: data)
        } catch {
            print("⚠️ SavedServersStore: failed to decode servers: \(error)")
            return []
        }
    }
}
