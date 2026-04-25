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
        case homeLayout
        case playback
        case streaming
        case subtitles
        case skip
        case parental
        case account
        case app
    }

    @ObservedObject private var layoutStore = HomeLayoutStore.shared

    private var layoutSubtitle: String {
        let visible = layoutStore.visibleCount
        let hidden = layoutStore.hiddenCount
        if visible == 0 && hidden == 0 { return "Reorder and hide rows" }
        if hidden == 0 { return "\(visible) visible" }
        return "\(visible) visible · \(hidden) hidden"
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Media Settings
                    VStack(spacing: 12) {
                        NavigationLink(destination: PlaybackSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "play.circle.fill",
                                title: "Playback",
                                subtitle: settingsManager.playbackSummary
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .playback)

                        NavigationLink(destination: StreamingSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "antenna.radiowaves.left.and.right",
                                title: "Streaming & Network",
                                subtitle: settingsManager.streamingSummary
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .streaming)

                        NavigationLink(destination: SubtitleSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "captions.bubble.fill",
                                title: "Subtitles",
                                subtitle: settingsManager.subtitleSummary
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .subtitles)

                        NavigationLink(destination: SkipSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "forward.fill",
                                title: "Auto-Skip",
                                subtitle: settingsManager.skipSummary
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .skip)

                        NavigationLink(destination: ParentalControlsSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "lock.shield.fill",
                                title: "Parental Controls",
                                subtitle: settingsManager.parentalControlsSummary
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .parental)
                    }

                    Rectangle()
                        .fill(Constants.Colors.divider)
                        .frame(height: 1)

                    // Account & App Settings
                    VStack(spacing: 12) {
                        NavigationLink(destination: HomeLayoutSettingsView()) {
                            SettingsRow(
                                icon: "square.stack.3d.up.fill",
                                title: "Home Layout",
                                subtitle: layoutSubtitle
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .homeLayout)

                        NavigationLink(destination: AccountSettingsView(authService: authService, settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "person.circle.fill",
                                title: "Account",
                                subtitle: authService.currentSession?.user.name ?? "Not signed in"
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .account)

                        NavigationLink(destination: AppSettingsView(settingsManager: settingsManager)) {
                            SettingsRow(
                                icon: "gear",
                                title: "App Settings",
                                subtitle: "Interface, storage, and more"
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .app)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 40)
            }
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
        HStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(Constants.Colors.accent)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
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

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}
