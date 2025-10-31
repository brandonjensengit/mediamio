//
//  LoginViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthenticationService

    let serverURL: String

    init(serverURL: String, authService: AuthenticationService) {
        self.serverURL = serverURL
        self.authService = authService

        // Load last username if available
        if let lastUsername = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.lastUsername) {
            username = lastUsername
        }

        // Load remember me preference
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.rememberMe) != nil {
            rememberMe = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.rememberMe)
        }
    }

    func login() async {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.login(
                serverURL: serverURL,
                username: username,
                password: password,
                rememberMe: rememberMe
            )

            // Save username for next time
            UserDefaults.standard.set(username, forKey: Constants.UserDefaultsKeys.lastUsername)

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
