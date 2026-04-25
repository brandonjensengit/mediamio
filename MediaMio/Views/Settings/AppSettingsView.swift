//
//  AppSettingsView.swift
//  MediaMio
//
//  App-level settings: theme, ratings + spoiler protection, cache
//  ceiling + clear-now action, version / build, open-source licenses,
//  and a "reset everything" knob. Card-style layout matching
//  `AccountSettingsView`.
//

import SwiftUI

private struct CacheCeilingOption {
    let mb: Int
    let label: String
}

private let cacheCeilingOptions: [CacheCeilingOption] = [
    .init(mb: 100,  label: "100 MB"),
    .init(mb: 500,  label: "500 MB"),
    .init(mb: 1000, label: "1 GB"),
    .init(mb: 2000, label: "2 GB"),
    .init(mb: 5000, label: "5 GB")
]

struct AppSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var cacheSize: String = "Calculating…"
    @State private var showClearCacheAlert = false

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: settingsManager.theme) ?? .dark
    }

    private var cacheCeilingLabel: String {
        cacheCeilingOptions.first(where: { $0.mb == settingsManager.cacheSize })?.label
            ?? "\(settingsManager.cacheSize) MB"
    }

    var body: some View {
        SettingsCardScreen(title: "App Settings") {
            SettingsSection("Interface", footer: "Spoiler protection hides episode thumbnails and descriptions until watched.") {
                SettingsPickerNavRow(
                    icon: "paintbrush.fill",
                    title: "Theme",
                    value: selectedTheme.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Theme",
                        selection: $settingsManager.theme,
                        options: AppTheme.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue)
                        }
                    )
                }

                SettingsToggleRow(
                    icon: "star.fill",
                    title: "Show Ratings",
                    isOn: $settingsManager.showRatings
                )

                SettingsToggleRow(
                    icon: "eye.slash.fill",
                    title: "Spoiler Protection",
                    isOn: $settingsManager.spoilerProtection
                )
            }

            SettingsSection("Storage", footer: "Cached images and data reduce loading time and bandwidth.") {
                SettingsValueRow(
                    icon: "internaldrive.fill",
                    title: "Cache Size",
                    value: cacheSize
                )

                SettingsPickerNavRow(
                    icon: "tray.full.fill",
                    title: "Maximum Cache Size",
                    value: cacheCeilingLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Maximum Cache Size",
                        selection: $settingsManager.cacheSize,
                        options: cacheCeilingOptions.map {
                            SettingsPickerOption(value: $0.mb, title: $0.label)
                        }
                    )
                }

                SettingsActionRow(
                    icon: "trash.fill",
                    title: "Clear Cache",
                    subtitle: "Delete all cached images and data",
                    tint: .red
                ) {
                    showClearCacheAlert = true
                }
            }

            SettingsSection("About") {
                SettingsValueRow(
                    icon: "app.fill",
                    title: "Version",
                    value: getAppVersion()
                )

                SettingsValueRow(
                    icon: "hammer.fill",
                    title: "Build",
                    value: getBuildNumber()
                )

                NavigationLink {
                    OpenSourceLicensesView()
                } label: {
                    SettingsCardRow {
                        HStack(spacing: 24) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Constants.Colors.accent)
                                .frame(width: 64, height: 64)

                            Text("Open Source Licenses")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .buttonStyle(.cardChrome)
            }

            SettingsSection("Debug", footer: "Restores every setting to its default value.") {
                SettingsActionRow(
                    icon: "arrow.counterclockwise",
                    title: "Reset All Settings",
                    tint: .orange
                ) {
                    settingsManager.resetToDefaults()
                }
            }
        }
        .onAppear {
            calculateCacheSize()
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all cached images and data. Loading times may briefly slow down.")
        }
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = URLCache.shared.currentDiskUsage
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            DispatchQueue.main.async {
                cacheSize = formatted
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        calculateCacheSize()
    }
}

// MARK: - Open Source Licenses View

struct OpenSourceLicensesView: View {
    var body: some View {
        SettingsCardScreen(title: "Open Source") {
            SettingsSection {
                LicenseCard(
                    name: "MediaMio",
                    description: "Jellyfin client for Apple TV",
                    license: "MIT License"
                )

                LicenseCard(
                    name: "SwiftUI",
                    description: "Apple's declarative UI framework",
                    license: "Apple Software License"
                )

                LicenseCard(
                    name: "AVFoundation",
                    description: "Apple's audio / video framework",
                    license: "Apple Software License"
                )
            }

            SettingsSectionFooter(
                text: "Built with SwiftUI and connects to your self-hosted Jellyfin server."
            )
        }
    }
}

private struct LicenseCard: View {
    let name: String
    let description: String
    let license: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            Text(license)
                .font(.caption)
                .foregroundColor(Constants.Colors.accent)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }
}

#Preview {
    NavigationStack {
        AppSettingsView(settingsManager: SettingsManager())
    }
}
