//
//  AppSettingsView.swift
//  MediaMio
//
//  App settings: theme, cache management, about
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var cacheSize: String = "Calculating..."
    @State private var showClearCacheAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                // Interface
                Section {
                    Picker("Theme", selection: $settingsManager.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                                .foregroundColor(.white)  // ALWAYS white
                                .listRowBackground(Color.black.opacity(0.3))
                        }
                    }
                    .pickerStyle(.segmented)
                    .foregroundColor(.white)  // ALWAYS white

                    Toggle("Show Ratings", isOn: $settingsManager.showRatings)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .listRowBackground(Color.black.opacity(0.3))

                    Toggle("Spoiler Protection", isOn: $settingsManager.spoilerProtection)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Interface")
                        .foregroundColor(.white)
                } footer: {
                    Text("Spoiler protection hides episode thumbnails and descriptions until watched")
                        .foregroundColor(.secondary)
                }

                // Storage & Cache
                Section {
                    HStack {
                        Text("Cache Size")
                            .foregroundColor(.white)
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }

                    Picker("Maximum Cache Size", selection: $settingsManager.cacheSize) {
                        Text("100 MB").tag(100)
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("500 MB").tag(500)
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("1 GB").tag(1000)
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("2 GB").tag(2000)
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("5 GB").tag(5000)
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))

                    Button(action: {
                        showClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cache")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Storage")
                        .foregroundColor(.white)
                } footer: {
                    Text("Cached images and data help reduce loading times and bandwidth usage")
                        .foregroundColor(.secondary)
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                            .foregroundColor(.white)
                        Spacer()
                        Text(getBuildNumber())
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: OpenSourceLicensesView()) {
                        SettingsRowWithFocus(
                            title: "Open Source Licenses"
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("About")
                        .foregroundColor(.white)
                }

                // Debug
                Section {
                    Button(action: {
                        settingsManager.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Reset All Settings")
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("Debug")
                        .foregroundColor(.white)
                } footer: {
                    Text("Reset all settings to their default values")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("App Settings")
        .onAppear {
            calculateCacheSize()
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all cached images and data. This may temporarily slow down loading times.")
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
            let urlCache = URLCache.shared
            let bytes = urlCache.currentDiskUsage

            DispatchQueue.main.async {
                cacheSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        calculateCacheSize()
        print("✅ Cache cleared")
    }
}

// MARK: - Open Source Licenses View

struct OpenSourceLicensesView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    LicenseSection(
                        name: "MediaMio",
                        description: "Jellyfin client for Apple TV",
                        license: "MIT License"
                    )

                    LicenseSection(
                        name: "SwiftUI",
                        description: "Apple's declarative UI framework",
                        license: "Apple Software License"
                    )

                    LicenseSection(
                        name: "AVFoundation",
                        description: "Apple's audio/video framework",
                        license: "Apple Software License"
                    )

                    Text("This app is built with love using SwiftUI and connects to your self-hosted Jellyfin server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding(60)
            }
        }
        .navigationTitle("Open Source Licenses")
    }
}

struct LicenseSection: View {
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
                .foregroundColor(.secondary)

            Text(license)
                .font(.caption)
                .foregroundColor(Color(hex: "667eea"))
                .padding(.top, 4)
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView(settingsManager: SettingsManager())
    }
}
