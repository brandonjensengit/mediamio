//
//  AccountSettingsView.swift
//  MediaMio
//
//  Account settings screen. Owns three responsibilities the rest of the
//  app didn't have a home for:
//    1. Show the active session (current user + server) as a hero card.
//    2. Let the user switch to or forget any *other* saved (server, user)
//       pair persisted in `SavedServersStore`.
//    3. Let the user add a new server while staying signed in to the
//       current one (push-presents `ServerEntryView` in add-server mode).
//
//  Sign-out lives here too, both regular and "scorched earth" variants.
//
//  Constraint: this view never reaches into the Keychain or persistence
//  directly. All multi-account operations route through
//  `AuthenticationService` / `SavedServersStore`, which own those edges.
//
//  Visual contract: matches the parent `SettingsView` card vocabulary
//  (custom ScrollView + surface1/surface3 row chrome, NOT SwiftUI Form).
//  The grouped-Form aesthetic was an iOS-density carry-over and read as
//  broken at 10 ft.
//

import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var settingsManager: SettingsManager
    @EnvironmentObject var savedServers: SavedServersStore

    @State private var showSignOutAlert = false
    @State private var showDeleteDataAlert = false
    @State private var pendingForget: (server: SavedServer, user: SavedUser)?
    @State private var switchError: String?
    @Environment(\.dismiss) private var dismiss

    /// Saved (server, user) pairs that aren't the active session — these are
    /// the rows the "Other Accounts" section renders. Sorted by user-level
    /// `lastUsedAt` so the most recently active sibling profile floats up.
    private var otherAccounts: [(server: SavedServer, user: SavedUser)] {
        let activeServer = authService.currentSession?.serverURL
        let activeUser = authService.currentSession?.user.id
        return savedServers.servers
            .flatMap { server in server.users.map { (server, $0) } }
            .filter { entry in
                !(entry.server.url == activeServer && entry.user.id == activeUser)
            }
            .sorted { $0.user.lastUsedAt > $1.user.lastUsedAt }
    }

    /// Friendly display name for the active server. Prefers the saved store's
    /// display name (set on first successful login), falls back to the URL
    /// host so we never leak a UUID or full URL into the hero card subtitle.
    private var activeServerName: String {
        guard let session = authService.currentSession else { return "" }
        if let saved = savedServers.servers.first(where: { $0.url == session.serverURL }) {
            return saved.name
        }
        return URL(string: session.serverURL)?.host ?? session.serverURL
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    inlineHeading

                    if let session = authService.currentSession {
                        currentSessionCard(session: session)
                    }

                    if !otherAccounts.isEmpty {
                        switchAccountSection
                    }

                    addServerSection

                    signOutSection
                }
                .padding(.horizontal, 80)
                .padding(.top, 40)
                .padding(.bottom, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Match the rest of the Settings stack: render the heading inline
        // inside the scroll view so the system's translucent navigation
        // title doesn't ghost over the hero card.
        .navigationBarHidden(true)
        .trackedPushedView()
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut(deleteData: false)
            }
        } message: {
            Text("Drops you at the server picker. Local cache is preserved.")
        }
        .alert("Sign Out & Delete Data", isPresented: $showDeleteDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete & Sign Out", role: .destructive) {
                signOut(deleteData: true)
            }
        } message: {
            Text("Wipes cached images and settings on this device. You cannot undo this action.")
        }
        .alert(
            "Forget Account",
            isPresented: Binding(
                get: { pendingForget != nil },
                set: { if !$0 { pendingForget = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingForget = nil }
            Button("Forget", role: .destructive) {
                if let target = pendingForget {
                    savedServers.forget(serverURL: target.server.url, userId: target.user.id)
                }
                pendingForget = nil
            }
        } message: {
            if let target = pendingForget {
                Text("Remove \(target.user.name) on \(target.server.name) from this device? You'll need to sign in again to use it.")
            }
        }
        .alert(
            "Couldn't Switch Accounts",
            isPresented: Binding(
                get: { switchError != nil },
                set: { if !$0 { switchError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { switchError = nil }
        } message: {
            Text(switchError ?? "")
        }
    }

    // MARK: - Heading

    private var inlineHeading: some View {
        Text("Account")
            .font(.system(size: 57, weight: .regular))
            .foregroundColor(.white)
    }

    // MARK: - Current session hero

    @ViewBuilder
    private func currentSessionCard(session: UserSession) -> some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.accent)
                    .frame(width: 96, height: 96)
                Text(session.user.name.prefix(1).uppercased())
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(session.user.name)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                    Text(activeServerName)
                        .font(.system(size: 23))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }

    // MARK: - Switch account

    @ViewBuilder
    private var switchAccountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Switch Account")

            VStack(spacing: 12) {
                ForEach(otherAccounts, id: \.user.id) { entry in
                    Button {
                        Task { await switchTo(server: entry.server, user: entry.user) }
                    } label: {
                        OtherAccountRow(server: entry.server, user: entry.user)
                    }
                    .buttonStyle(.cardChrome)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingForget = entry
                        } label: {
                            Label("Forget Account", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Add server

    @ViewBuilder
    private var addServerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel(otherAccounts.isEmpty ? "Servers" : "Add Server")

            NavigationLink {
                ServerEntryView(mode: .addServer)
                    .environmentObject(authService)
                    .environmentObject(savedServers)
            } label: {
                SettingsRow(
                    icon: "plus.circle.fill",
                    title: "Add Another Server",
                    subtitle: "Sign in to a different Jellyfin server"
                )
            }
            .buttonStyle(.cardChrome)
        }
    }

    // MARK: - Sign out

    @ViewBuilder
    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Sign Out")

            VStack(spacing: 12) {
                Button {
                    showSignOutAlert = true
                } label: {
                    DangerRow(
                        icon: "arrow.right.circle.fill",
                        title: "Sign Out",
                        subtitle: "Return to the server picker"
                    )
                }
                .buttonStyle(.cardChrome)

                Button {
                    showDeleteDataAlert = true
                } label: {
                    DangerRow(
                        icon: "trash.fill",
                        title: "Sign Out & Delete Local Data",
                        subtitle: "Wipes cached images and settings on this device"
                    )
                }
                .buttonStyle(.cardChrome)
            }
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 23, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .padding(.leading, 4)
    }

    // MARK: - Actions

    /// Silent re-login to a stored token. On success the active session
    /// changes, MainTabView's `.id(...)` flip remounts the tab tree, and
    /// this Account screen unmounts cleanly with the rest. On 401 the
    /// stored token has been revoked server-side — `signInWithSavedToken`
    /// raises `.authenticationFailed`; we surface that as a hint that
    /// the user should re-sign-in via "Add Another Server."
    private func switchTo(server: SavedServer, user: SavedUser) async {
        do {
            try await authService.signInWithSavedToken(server: server, user: user)
        } catch APIError.authenticationFailed {
            switchError = "That sign-in expired. Add the server again to refresh it."
        } catch {
            switchError = error.localizedDescription
        }
    }

    private func signOut(deleteData: Bool) {
        authService.logout()

        if deleteData {
            clearAllCache()
        }

        dismiss()
    }

    private func clearAllCache() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        URLCache.shared.removeAllCachedResponses()
        settingsManager.resetToDefaults()
    }
}

// MARK: - Rows

/// Row for a saved sibling profile in "Switch Account". Mirrors the
/// `SettingsRow` chrome (surface1 → surface3 on focus, 120pt min height,
/// chromeFocus lift) so the row vocabulary on this screen is identical to
/// the one a step up the navigation stack.
private struct OtherAccountRow: View {
    let server: SavedServer
    let user: SavedUser

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.accent.opacity(0.45))
                    .frame(width: 64, height: 64)
                Text(user.name.prefix(1).uppercased())
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(user.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(server.name)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: "arrow.left.arrow.right")
                .font(.title3)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(isFocused ? Constants.Colors.surface3 : Constants.Colors.surface1)
        )
        .chromeFocus()
    }
}

/// Destructive-action row for sign-out. Diverges from `SettingsRow` only
/// in the icon/title color treatment — same surface1/surface3 chrome and
/// dimensions so it doesn't read as foreign next to the other rows.
private struct DangerRow: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.red)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(isFocused ? Constants.Colors.surface3 : Constants.Colors.surface1)
        )
        .chromeFocus()
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView(
            authService: AuthenticationService(apiClient: JellyfinAPIClient()),
            settingsManager: SettingsManager()
        )
        .environmentObject(SavedServersStore())
    }
}
