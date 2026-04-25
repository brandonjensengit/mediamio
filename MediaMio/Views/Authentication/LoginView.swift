//
//  LoginView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    let serverURL: String
    let serverName: String

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = true
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showQuickConnect: Bool = false
    @State private var quickConnectAvailable: Bool = false

    init(serverURL: String, serverName: String) {
        self.serverURL = serverURL
        self.serverName = serverName

        // Load last username if available
        if let lastUsername = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.lastUsername) {
            _username = State(initialValue: lastUsername)
        }

        // Load remember me preference
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.rememberMe) != nil {
            _rememberMe = State(initialValue: UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.rememberMe))
        }
    }

    var body: some View {
        ZStack {
            // Background
            Constants.Colors.background.ignoresSafeArea()

            if isLoading {
                LoadingView(message: "Signing in...")
            } else {
                VStack(spacing: 40) {
                    Spacer()

                    // Brand wordmark + small server-context line. Replaces
                    // the oversized server-rack icon + 48pt server name —
                    // the page is about signing in, not broadcasting the
                    // server's identity.
                    VStack(spacing: 18) {
                        GloxxWordmark(size: 72)

                        VStack(spacing: 6) {
                            Text(serverName)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.85))

                            Text(serverURL)
                                .font(.callout)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Login form
                    VStack(spacing: 30) {
                        // Username field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Username")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            TextField("Enter username", text: $username)
                                .textFieldStyle(.plain)
                                .font(.title2)
                                .padding()
                                .background(Constants.Colors.cardBackground)
                                .cornerRadius(Constants.UI.cornerRadius)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onSubmit {
                                    // Move focus to password field
                                }
                        }
                        .frame(width: 700)

                        // Password field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Password")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            SecureField("Enter password", text: $password)
                                .textFieldStyle(.plain)
                                .font(.title2)
                                .padding()
                                .background(Constants.Colors.cardBackground)
                                .cornerRadius(Constants.UI.cornerRadius)
                                .onSubmit {
                                    Task {
                                        await login()
                                    }
                                }
                        }
                        .frame(width: 700)

                        // Remember me toggle
                        Toggle(isOn: $rememberMe) {
                            Text("Remember Me")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(width: 700)

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.title3)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(width: 700)
                        }

                        // Action buttons
                        VStack(spacing: 20) {
                            FocusableButton(title: "Sign In", style: .primary) {
                                Task {
                                    await login()
                                }
                            }

                            if quickConnectAvailable {
                                FocusableButton(title: "Use Quick Connect", style: .secondary) {
                                    showQuickConnect = true
                                }
                            }

                            FocusableButton(title: "Back", style: .secondary) {
                                dismiss()
                            }
                        }
                        .frame(width: 700)
                    }

                    Spacer()
                    Spacer()
                }
                .padding(Constants.UI.defaultPadding)
            }
        }
        .task {
            // Hide the Quick Connect button for servers that don't expose it
            // (older Jellyfin, or admins who turned it off). We don't block
            // password login on the result — the check is fire-and-forget.
            quickConnectAvailable = await authService.isQuickConnectAvailable(serverURL: serverURL)
        }
        // Push QuickConnectView onto the surrounding NavigationStack
        // instead of layering a second full-screen cover on top of
        // LoginView's own. Nested covers don't reliably present on tvOS
        // and the Menu button can't dismiss either layer; a stack push
        // gives both Menu and the on-screen Back a single consistent way
        // to navigate back to LoginView.
        .navigationDestination(isPresented: $showQuickConnect) {
            QuickConnectView(serverURL: serverURL, rememberMe: rememberMe, serverName: serverName)
                .environmentObject(authService)
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
                rememberMe: rememberMe,
                serverName: serverName
            )

            // Save username for next time
            UserDefaults.standard.set(username, forKey: Constants.UserDefaultsKeys.lastUsername)

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    LoginView(serverURL: "http://192.168.1.100:8096", serverName: "My Jellyfin Server")
}
