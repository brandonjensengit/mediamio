//
//  SettingsView.swift
//  MediaMio
//
//  Main settings screen with navigation to all settings categories
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var settingsManager = SettingsManager()
    @FocusState private var focusedField: SettingsField?

    enum SettingsField: Hashable {
        case playback
        case streaming
        case subtitles
        case skip
        case account
        case app
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                // Media Settings
                Section {
                    NavigationLink(destination: PlaybackSettingsView(settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "play.circle.fill",
                            title: "Playback",
                            subtitle: settingsManager.playbackSummary
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .playback)

                    NavigationLink(destination: StreamingSettingsView(settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Streaming & Network",
                            subtitle: settingsManager.streamingSummary
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .streaming)

                    NavigationLink(destination: SubtitleSettingsView(settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "captions.bubble.fill",
                            title: "Subtitles",
                            subtitle: settingsManager.subtitleSummary
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .subtitles)

                    NavigationLink(destination: SkipSettingsView(settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "forward.fill",
                            title: "Auto-Skip",
                            subtitle: settingsManager.skipSummary
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .skip)
                }

                // Account & App Settings
                Section {
                    NavigationLink(destination: AccountSettingsView(authService: authService, settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "person.circle.fill",
                            title: "Account",
                            subtitle: authService.currentSession?.user.name ?? "Not signed in"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .account)

                    NavigationLink(destination: AppSettingsView(settingsManager: settingsManager)) {
                        SettingsRow(
                            icon: "gear",
                            title: "App Settings",
                            subtitle: "Interface, storage, and more"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black.opacity(0.3))
                    .focused($focusedField, equals: .app)
                }
            }
            .listStyle(.grouped)
            .buttonStyle(.plain)
        }
        .navigationTitle("Settings")
        .onAppear {
            print("⚙️ SettingsView appeared")
            focusedField = .playback
            if let user = authService.currentSession?.user {
                settingsManager.updateUserInfo(name: user.name, imageURL: nil)
                print("✅ Settings loaded for user: \(user.name)")
            } else {
                print("⚠️ No user session found in Settings")
            }
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "667eea"))
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)  // ALWAYS white

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Color(hex: "667eea").opacity(0.2) : Color.clear)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
