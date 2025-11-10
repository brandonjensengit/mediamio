//
//  SkipSettingsView.swift
//  MediaMio
//
//  Auto-skip settings: intros, credits, recaps
//

import SwiftUI

struct SkipSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedSkipBehavior: SkipBehavior {
        SkipBehavior(rawValue: settingsManager.skipBehavior) ?? .buttonWithDelay
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                // Intros
                Section {
                    Toggle("Auto-Skip Intros", isOn: $settingsManager.autoSkipIntros)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))

                        .listRowBackground(Color.black.opacity(0.3))
                    Toggle("Show Skip Button", isOn: $settingsManager.showSkipIntroButton)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .disabled(!settingsManager.autoSkipIntros)
                        .listRowBackground(Color.black.opacity(0.3))

                    if settingsManager.autoSkipIntros {
                        Picker("Skip After", selection: $settingsManager.skipIntroCountdown) {
                            Text("Instantly").tag(0)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                            Text("3 seconds").tag(3)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                            Text("5 seconds").tag(5)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        }
                        .pickerStyle(.segmented)
                        .foregroundColor(.white)  // ALWAYS white
                    }
                } header: {
                    Text("Intros")
                        .foregroundColor(.white)
                } footer: {
                    if settingsManager.autoSkipIntros {
                        Text("Opening credits will be skipped automatically")
                            .foregroundColor(.secondary)
                    } else {
                        Text("A 'Skip Intro' button will appear during opening credits")
                            .foregroundColor(.secondary)
                    }
                }

                // Credits
                Section {
                    Toggle("Auto-Skip Credits", isOn: $settingsManager.autoSkipCredits)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))

                        .listRowBackground(Color.black.opacity(0.3))
                    Toggle("Show Next Episode Overlay", isOn: $settingsManager.showNextEpisodeOverlay)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .disabled(!settingsManager.autoSkipCredits)
                        .listRowBackground(Color.black.opacity(0.3))

                    if settingsManager.autoSkipCredits {
                        Picker("Start Next Episode After", selection: $settingsManager.skipCreditsCountdown) {
                            Text("5 seconds").tag(5)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                            Text("10 seconds").tag(10)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                            Text("15 seconds").tag(15)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                            Text("20 seconds").tag(20)
                                .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        }
                        .pickerStyle(.segmented)
                        .foregroundColor(.white)  // ALWAYS white
                    }
                } header: {
                    Text("Credits")
                        .foregroundColor(.white)
                } footer: {
                    if settingsManager.autoSkipCredits {
                        Text("Next episode will start automatically during end credits")
                            .foregroundColor(.secondary)
                    } else {
                        Text("A 'Next Episode' button will appear during end credits")
                            .foregroundColor(.secondary)
                    }
                }

                // Recaps
                Section {
                    Toggle("Auto-Skip Recaps", isOn: $settingsManager.autoSkipRecaps)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))

                        .listRowBackground(Color.black.opacity(0.3))
                    Toggle("Show Skip Button", isOn: $settingsManager.showSkipRecapButton)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .disabled(!settingsManager.autoSkipRecaps)
                        .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Recaps")
                        .foregroundColor(.white)
                } footer: {
                    Text("Skip 'Previously on...' segments at the start of episodes")
                        .foregroundColor(.secondary)
                }

                // Skip Behavior
                Section {
                    Picker("Skip Behavior", selection: $settingsManager.skipBehavior) {
                        ForEach(SkipBehavior.allCases) { behavior in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(behavior.rawValue)
                                    .foregroundColor(.white)  // ALWAYS white
                                Text(behavior.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(behavior.rawValue)
                            .listRowBackground(Color.black.opacity(0.3))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("General Behavior")
                        .foregroundColor(.white)
                } footer: {
                    Text(selectedSkipBehavior.description)
                        .foregroundColor(.secondary)
                }

                // Info
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)

                        Text("Skip markers are provided by your Jellyfin server and may not be available for all content. Accuracy depends on server-side detection.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Auto-Skip")
    }
}

#Preview {
    NavigationStack {
        SkipSettingsView(settingsManager: SettingsManager())
    }
}
