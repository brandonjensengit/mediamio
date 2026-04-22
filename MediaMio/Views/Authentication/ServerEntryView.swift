//
//  ServerEntryView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct ServerEntryView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var savedServers: SavedServersStore
    @StateObject private var discovery = ServerDiscoveryService()

    @State private var showingLogin = false
    @State private var serverURL: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var serverInfo: ServerInfo? = nil
    @State private var isConnected: Bool = false

    init() {
        if let lastURL = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.lastServerURL) {
            _serverURL = State(initialValue: lastURL)
        }
    }

    /// Flattened (server × user) list sorted by user-level lastUsedAt so the
    /// most recently active profile floats to the top — closer to Netflix's
    /// "pick up where you left off" profile picker than a nested tree would be.
    private var savedProfiles: [(server: SavedServer, user: SavedUser)] {
        savedServers.servers
            .flatMap { server in server.users.map { (server, $0) } }
            .sorted { $0.user.lastUsedAt > $1.user.lastUsedAt }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                LoadingView(message: "Connecting to server...")
            } else {
                content
            }
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
        .onChange(of: isConnected) { oldValue, newValue in
            print("🔄 isConnected changed from \(oldValue) to \(newValue)")
            if newValue {
                print("✅ Connection successful, showing login")
                print("📝 Server info: \(serverInfo?.serverName ?? "nil")")
                showingLogin = true
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
                }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 40) {
                header

                savedProfilesSection

                discoveredSection

                manualEntrySection

                if let error = errorMessage {
                    Text(error)
                        .font(.title3)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 700)
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical, 60)
            .padding(.horizontal, Constants.UI.defaultPadding)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
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
        .padding(.top, 20)
    }

    // MARK: - Saved profiles

    @ViewBuilder
    private var savedProfilesSection: some View {
        if !savedProfiles.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Constants.Colors.primary)
                    Text("Recent")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(savedProfiles, id: \.user.id) { entry in
                        SavedProfileRow(server: entry.server, user: entry.user) {
                            Task { await selectSavedProfile(server: entry.server, user: entry.user) }
                        }
                    }
                }
            }
            .frame(width: 700)
        }
    }

    // MARK: - Discovered servers

    @ViewBuilder
    private var discoveredSection: some View {
        if !discovery.servers.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "wifi")
                        .foregroundColor(Constants.Colors.primary)
                    Text("On This Network")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(discovery.servers) { server in
                        DiscoveredServerRow(server: server) {
                            serverURL = server.url
                            Task { await validateAndConnect() }
                        }
                    }
                }
            }
            .frame(width: 700)
        }
    }

    // MARK: - Manual entry

    private var manualEntrySection: some View {
        VStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Or Enter Server Address")
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
                        Task { await validateAndConnect() }
                    }
            }
            .frame(width: 700)

            FocusableButton(title: "Connect", style: .primary) {
                Task { await validateAndConnect() }
            }
            .frame(width: 700)
        }
    }

    // MARK: - Saved profile selection

    /// Kick off a login flow for a stored (server, user) pair. Pre-fills the
    /// username so `LoginView` can pick it up from `UserDefaults` on init,
    /// then reuses `validateAndConnect` so the existing error-path handling
    /// (unreachable server, bad URL) stays identical to manual entry.
    ///
    /// Note: this only pre-populates. Silent re-login using the stored token
    /// is wired in a follow-up commit — tapping a saved profile today still
    /// drops into the password prompt.
    private func selectSavedProfile(server: SavedServer, user: SavedUser) async {
        UserDefaults.standard.set(user.name, forKey: Constants.UserDefaultsKeys.lastUsername)
        serverURL = server.url
        await validateAndConnect()
    }

    // MARK: - Connect

    func validateAndConnect() async {
        guard !serverURL.isEmpty else {
            errorMessage = "Please enter a server URL"
            return
        }

        isLoading = true
        errorMessage = nil

        let normalizedURL = authService.normalizeServerURL(serverURL)

        do {
            let info = try await authService.testServerConnection(serverURL: normalizedURL)
            print("📥 Received server info: \(info.serverName)")
            serverInfo = info
            isConnected = true

            serverURL = normalizedURL
            UserDefaults.standard.set(normalizedURL, forKey: Constants.UserDefaultsKeys.lastServerURL)

        } catch {
            print("❌ Connection failed: \(error)")
            isConnected = false

            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else if let urlError = error as? URLError {
                errorMessage = "Network error: \(urlError.localizedDescription)\nCode: \(urlError.code.rawValue)"
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }
}

// MARK: - Rows

private struct SavedProfileRow: View {
    let server: SavedServer
    let user: SavedUser
    let action: () -> Void

    @Environment(\.isFocused) private var envFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(server.name)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Constants.Colors.cardBackground)
            .cornerRadius(Constants.UI.cornerRadius)
            .scaleEffect(envFocused ? Constants.UI.focusScale : Constants.UI.normalScale)
            .shadow(
                color: envFocused ? .white.opacity(0.4) : .clear,
                radius: Constants.UI.focusShadowRadius
            )
            .animation(.easeInOut(duration: Constants.UI.animationDuration), value: envFocused)
        }
        .buttonStyle(.plain)
    }
}

private struct DiscoveredServerRow: View {
    let server: ServerDiscoveryService.DiscoveredServer
    let action: () -> Void

    @Environment(\.isFocused) private var envFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(server.url)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Constants.Colors.cardBackground)
            .cornerRadius(Constants.UI.cornerRadius)
            .scaleEffect(envFocused ? Constants.UI.focusScale : Constants.UI.normalScale)
            .shadow(
                color: envFocused ? .white.opacity(0.4) : .clear,
                radius: Constants.UI.focusShadowRadius
            )
            .animation(.easeInOut(duration: Constants.UI.animationDuration), value: envFocused)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ServerEntryView()
        .environmentObject(AuthenticationService())
        .environmentObject(SavedServersStore())
}
