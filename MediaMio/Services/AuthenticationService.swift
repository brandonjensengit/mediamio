//
//  AuthenticationService.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentSession: UserSession?
    @Published var isAuthenticated: Bool = false

    private let apiClient: JellyfinAPIClient
    private let keychain = KeychainHelper.shared
    let savedServers: SavedServersStore

    // `apiClient` and `savedServers` default to nil with a fresh-instance
    // fallback so SwiftUI Previews can keep using `AuthenticationService()`
    // unchanged. Production paths inject the shared instances built in
    // `MediaMioApp.init`. The nil fallback runs inside this MainActor-
    // isolated body, dodging Swift 6's nonisolated-default-arg evaluation.
    init(apiClient: JellyfinAPIClient? = nil, savedServers: SavedServersStore? = nil) {
        let store = savedServers ?? SavedServersStore()
        self.savedServers = store
        self.apiClient = apiClient ?? JellyfinAPIClient()

        // Seed the saved-servers store from the legacy single-blob slot on
        // first launch after the upgrade, so users don't get signed out.
        store.migrateLegacySingleBlobIfNeeded()

        // Try to restore session from keychain
        restoreSession()
    }

    // MARK: - Session Management
    func restoreSession() {
        guard let credentials = keychain.retrieveCredentials() else {
            return
        }

        // Configure API client
        apiClient.configure(baseURL: credentials.serverURL, accessToken: credentials.accessToken)

        // Create session
        let user = User(
            id: credentials.userId,
            name: credentials.username,
            serverId: "",
            hasPassword: true,
            hasConfiguredPassword: true
        )

        currentSession = UserSession(
            user: user,
            accessToken: credentials.accessToken,
            serverURL: credentials.serverURL,
            serverId: ""
        )

        isAuthenticated = true
    }

    func saveSession(
        _ session: UserSession,
        rememberMe: Bool = true,
        serverName: String? = nil
    ) throws {
        currentSession = session
        isAuthenticated = true

        // Save to UserDefaults
        UserDefaults.standard.set(rememberMe, forKey: Constants.UserDefaultsKeys.rememberMe)

        if rememberMe {
            // Save to keychain (legacy single-blob slot — kept so a downgrade
            // of the app doesn't lose the current session)
            try keychain.saveCredentials(
                serverURL: session.serverURL,
                username: session.user.name,
                accessToken: session.accessToken,
                userId: session.user.id
            )

            // And save to the saved-servers store — the source of truth for
            // the multi-user picker. `serverName` comes from `ServerInfo`
            // when available; otherwise we reuse the current server's saved
            // name or fall back to the host.
            let name = serverName
                ?? savedServers.servers.first(where: { $0.url == session.serverURL })?.name
                ?? URL(string: session.serverURL)?.host
                ?? session.serverURL
            savedServers.remember(
                serverURL: session.serverURL,
                serverName: name,
                user: session.user,
                accessToken: session.accessToken
            )
        }
    }

    /// Clear the active in-memory session but leave the saved-servers list
    /// alone — matches the "sign out" UX where you drop back to the profile
    /// picker and can tap yourself to sign in again. Use `forget` on the
    /// store to actually purge a saved profile.
    func clearSession() {
        currentSession = nil
        isAuthenticated = false
        keychain.clearCredentials()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.rememberMe)
        // Reset the shared client so any in-flight or post-logout request
        // uses an empty token rather than the just-revoked one. Previously
        // an `AppEnvironment` Combine bridge handled this — that bridge is
        // gone now that the client is unified.
        apiClient.configure(baseURL: "", accessToken: "")
    }

    // MARK: - Server Connection
    func testServerConnection(serverURL: String) async throws -> ServerInfo {
        // Validate URL format
        guard isValidURL(serverURL) else {
            print("❌ Invalid URL format: \(serverURL)")
            throw APIError.invalidURL
        }

        print("🔍 Testing connection to: \(serverURL)")

        // Test connection - let the actual error propagate
        let serverInfo = try await apiClient.testConnection(serverURL: serverURL)
        print("✅ Connection successful to: \(serverInfo.serverName)")
        return serverInfo
    }

    // MARK: - Authentication
    func login(
        serverURL: String,
        username: String,
        password: String,
        rememberMe: Bool = true,
        serverName: String? = nil
    ) async throws {
        // Configure API client with server URL
        apiClient.configure(baseURL: serverURL)

        // Authenticate
        let authResult = try await apiClient.authenticate(username: username, password: password)

        // Create session
        let session = UserSession(
            user: authResult.user,
            accessToken: authResult.accessToken,
            serverURL: serverURL,
            serverId: authResult.serverId
        )

        // Save session
        try saveSession(session, rememberMe: rememberMe, serverName: serverName)
    }

    func logout() {
        clearSession()
    }

    // MARK: - Silent re-login

    /// Reuse a stored (server, user) access token to skip the password
    /// prompt. Called when the user taps an entry in the saved-profiles
    /// picker — the stored token is validated against `GET /Users/{id}`
    /// before we flip `isAuthenticated`, so a silently-revoked token can't
    /// leave the app in a "signed in" state that blows up on every
    /// subsequent request.
    ///
    /// On `APIError.authenticationFailed` (401), the stored token is
    /// cleared — it's been revoked server-side and would only keep failing.
    /// Other errors (network, server unreachable) leave the token alone so
    /// the user can retry without losing their profile.
    func signInWithSavedToken(server: SavedServer, user: SavedUser) async throws {
        guard let token = savedServers.token(for: server, user: user) else {
            throw APIError.authenticationFailed
        }

        apiClient.configure(baseURL: server.url, accessToken: token)

        do {
            let freshUser = try await apiClient.getCurrentUser(userId: user.id)

            let session = UserSession(
                user: freshUser,
                accessToken: token,
                serverURL: server.url,
                serverId: freshUser.serverId
            )

            // `saveSession` rewrites the legacy single-blob Keychain slot
            // so a subsequent launch's `restoreSession()` still finds this
            // user. It also bumps the `lastUsedAt` timestamps in the store.
            try saveSession(session, rememberMe: true, serverName: server.name)
        } catch APIError.authenticationFailed {
            // Token is no longer valid on the server — drop it so the user
            // gets cleanly bounced to the password prompt next time.
            savedServers.forget(serverURL: server.url, userId: user.id)
            throw APIError.authenticationFailed
        }
    }

    // MARK: - Quick Connect
    // Quick Connect lets the user approve this TV from another device (phone, web)
    // without entering a password on the remote. The VM owns the polling loop;
    // this service exposes three primitives the VM calls in sequence:
    //   1) initiate → get a 6-digit code to show on screen
    //   2) check    → poll every ~2s until approved
    //   3) finalize → trade the approved secret for a real session

    func isQuickConnectAvailable(serverURL: String) async -> Bool {
        apiClient.configure(baseURL: serverURL)
        return await apiClient.isQuickConnectEnabled()
    }

    func initiateQuickConnect(serverURL: String) async throws -> QuickConnectResult {
        apiClient.configure(baseURL: serverURL)
        return try await apiClient.initiateQuickConnect()
    }

    func pollQuickConnect(secret: String) async throws -> QuickConnectResult {
        try await apiClient.checkQuickConnectStatus(secret: secret)
    }

    func completeQuickConnect(
        serverURL: String,
        secret: String,
        rememberMe: Bool = true,
        serverName: String? = nil
    ) async throws {
        apiClient.configure(baseURL: serverURL)
        let authResult = try await apiClient.authenticateWithQuickConnect(secret: secret)

        let session = UserSession(
            user: authResult.user,
            accessToken: authResult.accessToken,
            serverURL: serverURL,
            serverId: authResult.serverId
        )
        try saveSession(session, rememberMe: rememberMe, serverName: serverName)
    }

    // MARK: - Validation
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        // Check if it has a scheme
        guard let scheme = url.scheme else {
            return false
        }

        // Only allow http and https
        guard scheme == "http" || scheme == "https" else {
            return false
        }

        // Check if it has a host
        guard url.host != nil else {
            return false
        }

        return true
    }

    func normalizeServerURL(_ urlString: String) -> String {
        var normalized = urlString.trimmingCharacters(in: .whitespaces)

        // Add http:// if no scheme is provided
        if !normalized.contains("://") {
            normalized = "http://\(normalized)"
        }

        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized
    }
}
