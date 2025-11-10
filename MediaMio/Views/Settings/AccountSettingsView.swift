//
//  AccountSettingsView.swift
//  MediaMio
//
//  Account settings: user profile, server info, sign out
//

import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var settingsManager: SettingsManager
    @State private var showSignOutAlert = false
    @State private var showDeleteDataAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                // User Profile
                if let session = authService.currentSession {
                    Section {
                        HStack(spacing: 20) {
                            // User avatar placeholder
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "667eea"))
                                    .frame(width: 80, height: 80)

                                Text(session.user.name.prefix(1).uppercased())
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.user.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Text(session.user.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("User")
                            .foregroundColor(.white)
                    }

                    // Server Information
                    Section {
                        HStack {
                            Text("Server")
                                .foregroundColor(.white)
                            Spacer()
                            Text(session.serverURL)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        HStack {
                            Text("Connection")
                                .foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 10, height: 10)
                                Text("Connected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Server")
                            .foregroundColor(.white)
                    }
                }

                // Actions
                Section {
                    Button(action: {
                        showSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)

                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }

                    Button(action: {
                        showDeleteDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .font(.title3)

                            Text("Sign Out & Delete Local Data")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Account")
                        .foregroundColor(.white)
                } footer: {
                    Text("Signing out will return you to the login screen. You can choose to keep or delete cached data.")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Account")
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut(deleteData: false)
            }
        } message: {
            Text("Are you sure you want to sign out? Your local cache will be preserved.")
        }
        .alert("Sign Out & Delete Data", isPresented: $showDeleteDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete & Sign Out", role: .destructive) {
                signOut(deleteData: true)
            }
        } message: {
            Text("Are you sure? This will delete all cached images and data. You cannot undo this action.")
        }
    }

    private func signOut(deleteData: Bool) {
        // Clear session
        authService.logout()

        if deleteData {
            // Clear all cached data
            clearAllCache()
        }

        // Dismiss settings and return to login
        dismiss()
    }

    private func clearAllCache() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Reset settings to defaults
        settingsManager.resetToDefaults()

        print("✅ All cache and local data cleared")
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView(
            authService: AuthenticationService(),
            settingsManager: SettingsManager()
        )
    }
}
