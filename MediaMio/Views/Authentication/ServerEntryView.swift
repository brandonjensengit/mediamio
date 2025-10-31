//
//  ServerEntryView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct ServerEntryView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingLogin = false
    @State private var serverURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var serverInfo: ServerInfo? = nil
    @State private var isConnected: Bool = false

    init() {
        // Load last used server URL if available
        if let lastURL = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.lastServerURL) {
            _serverURL = State(initialValue: lastURL)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if isLoading {
                LoadingView(message: "Connecting to server...")
            } else {
                VStack(spacing: 40) {
                    Spacer()

                    // App branding
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Constants.Colors.primary)

                        Text("MediaMio")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)

                        Text("Premium Jellyfin Client")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Server entry section
                    VStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Server Address")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            TextField("http://192.168.1.100:8096", text: $serverURL)
                                .textFieldStyle(.plain)
                                .font(.title2)
                                .padding()
                                .background(Constants.Colors.cardBackground)
                                .cornerRadius(Constants.UI.cornerRadius)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                                .onSubmit {
                                    Task {
                                        await validateAndConnect()
                                    }
                                }
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

                        // Connect button
                        FocusableButton(title: "Connect", style: .primary) {
                            Task {
                                await validateAndConnect()
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
        .onChange(of: isConnected) { oldValue, newValue in
            print("🔄 isConnected changed from \(oldValue) to \(newValue)")
            if newValue {
                print("✅ Connection successful, showing login")
                print("📝 Server info: \(serverInfo?.serverName ?? "nil")")
                showingLogin = true
                print("🎬 showingLogin set to: \(showingLogin)")
            }
        }
        .fullScreenCover(isPresented: $showingLogin) {
            Group {
                if let serverInfo = serverInfo {
                    LoginView(
                        serverURL: serverURL,
                        serverName: serverInfo.serverName
                    )
                    .environmentObject(authService)
                    .onAppear {
                        print("🔐 LoginView appeared for: \(serverInfo.serverName)")
                    }
                } else {
                    Text("Error: Server info not available")
                        .foregroundColor(.red)
                        .onAppear {
                            print("❌ serverInfo is nil in fullScreenCover")
                        }
                }
            }
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
            print("📥 Received server info: \(info.serverName)")
            serverInfo = info
            print("💾 Set serverInfo to: \(serverInfo?.serverName ?? "nil")")
            isConnected = true
            print("✅ Set isConnected to: \(isConnected)")

            // Save the validated URL
            serverURL = normalizedURL
            UserDefaults.standard.set(normalizedURL, forKey: Constants.UserDefaultsKeys.lastServerURL)
            print("💿 Saved URL: \(normalizedURL)")

        } catch {
            print("❌ Connection failed: \(error)")
            isConnected = false

            // Show more detailed error message
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else if let urlError = error as? URLError {
                errorMessage = "Network error: \(urlError.localizedDescription)\nCode: \(urlError.code.rawValue)"
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }

            print("📱 Showing error to user: \(errorMessage ?? "unknown")")
        }

        isLoading = false
    }
}

#Preview {
    ServerEntryView()
}
