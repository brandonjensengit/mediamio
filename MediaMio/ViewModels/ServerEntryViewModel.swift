//
//  ServerEntryViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class ServerEntryViewModel: ObservableObject {
    @Published var serverURL: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var serverInfo: ServerInfo?
    @Published var isConnected: Bool = false

    private let authService: AuthenticationService

    init(authService: AuthenticationService) {
        self.authService = authService

        // Load last used server URL if available
        if let lastURL = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.lastServerURL) {
            serverURL = lastURL
        }
    }

    func validateAndConnect() async {
        guard !serverURL.isEmpty else {
            errorMessage = "Please enter a server URL"
            return
        }

        isLoading = true
        errorMessage = nil

        // Normalize URL
        let normalizedURL = authService.normalizeServerURL(serverURL)

        do {
            let info = try await authService.testServerConnection(serverURL: normalizedURL)
            serverInfo = info
            isConnected = true

            // Save the validated URL
            serverURL = normalizedURL
            UserDefaults.standard.set(normalizedURL, forKey: Constants.UserDefaultsKeys.lastServerURL)

        } catch {
            isConnected = false
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func reset() {
        isConnected = false
        serverInfo = nil
        errorMessage = nil
    }
}
