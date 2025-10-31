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

    init() {
        // Initialize API client
        self.apiClient = JellyfinAPIClient()

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

    func saveSession(_ session: UserSession, rememberMe: Bool = true) throws {
        currentSession = session
        isAuthenticated = true

        // Save to UserDefaults
        UserDefaults.standard.set(rememberMe, forKey: Constants.UserDefaultsKeys.rememberMe)

        if rememberMe {
            // Save to keychain
            try keychain.saveCredentials(
                serverURL: session.serverURL,
                username: session.user.name,
                accessToken: session.accessToken,
                userId: session.user.id
            )
        }
    }

    func clearSession() {
        currentSession = nil
        isAuthenticated = false
        keychain.clearCredentials()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.rememberMe)
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
        rememberMe: Bool = true
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
        try saveSession(session, rememberMe: rememberMe)
    }

    func logout() {
        clearSession()
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
