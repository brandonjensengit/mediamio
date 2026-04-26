//
//  LoginView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService

    let serverURL: String
    let serverName: String
    /// Explicit pop callback supplied by the presenter. We don't rely on
    /// `\.dismiss` here — on tvOS 18, dismiss() sometimes resolves to the
    /// wrong scope when LoginView is itself a `navigationDestination` of a
    /// pushed parent (the new Settings → Account → Add Server flow). The
    /// caller flips its own `isPresented` binding instead, which always
    /// pops the right level.
    let onBack: () -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = true
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var quickConnectAvailable: Bool = false

    init(serverURL: String, serverName: String, onBack: @escaping () -> Void) {
        self.serverURL = serverURL
        self.serverName = serverName
        self.onBack = onBack

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

                        // Action buttons. Each is rendered unconditionally so
                        // tvOS focus traversal doesn't get re-evaluated when
                        // `quickConnectAvailable` flips after the async probe
                        // — re-evaluation can leave focus stuck on Sign In
                        // with Down failing to reach the buttons below.
                        VStack(spacing: 20) {
                            FocusableButton(title: "Sign In", style: .primary) {
                                Task {
                                    await login()
                                }
                            }

                            // NavigationLink instead of state-binding +
                            // .navigationDestination(isPresented:): on tvOS
                            // 18 a destination registered on a view that's
                            // itself a navigationDestination of a parent
                            // sometimes refuses to present. NavigationLink
                            // pushes deterministically.
                            QuickConnectNavLink(
                                serverURL: serverURL,
                                rememberMe: rememberMe,
                                serverName: serverName,
                                isEnabled: quickConnectAvailable
                            )
                            .environmentObject(authService)

                            FocusableButton(title: "Back", style: .secondary) {
                                onBack()
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

// MARK: - Quick Connect link

/// Card-button-shaped `NavigationLink` to `QuickConnectView`. Mirrors
/// `CTAButton` chrome (surface2 fill, 80pt height, cornerRadius, chromeFocus
/// lift) so it sits flush in the auth-screen button stack.
///
/// Why this isn't a `FocusableButton` setting `showQuickConnect = true`:
/// see the call site — chained `navigationDestination(isPresented:)`
/// registrations don't reliably present on tvOS 18 when LoginView is
/// itself a destination of a parent stack push.
private struct QuickConnectNavLink: View {
    let serverURL: String
    let rememberMe: Bool
    let serverName: String
    let isEnabled: Bool

    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        NavigationLink {
            QuickConnectView(serverURL: serverURL, rememberMe: rememberMe, serverName: serverName)
                .environmentObject(authService)
        } label: {
            HStack(spacing: 12) {
                Text("Use Quick Connect")
            }
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(Constants.Colors.surface2)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .buttonStyle(.cardChrome)
        .chromeFocus()
        .disabled(!isEnabled)
    }
}

#Preview {
    LoginView(serverURL: "http://192.168.1.100:8096", serverName: "My Jellyfin Server", onBack: {})
}
