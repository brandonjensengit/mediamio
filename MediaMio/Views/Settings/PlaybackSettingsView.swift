//
//  PlaybackSettingsView.swift
//  MediaMio
//
//  Playback settings: video quality, audio, auto-play behavior
//

import SwiftUI

struct PlaybackSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedVideoQuality: VideoQuality {
        VideoQuality(rawValue: settingsManager.videoQuality) ?? .auto
    }

    private var selectedAudioQuality: AudioQuality {
        AudioQuality(rawValue: settingsManager.audioQuality) ?? .high
    }

    private var selectedResumeBehavior: ResumeBehavior {
        ResumeBehavior(rawValue: settingsManager.resumeBehavior) ?? .alwaysAsk
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            Form {
                // Video Quality
                Section {
                    Picker("Video Quality", selection: $settingsManager.videoQuality) {
                        ForEach(VideoQuality.allCases) { quality in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quality.rawValue)
                                    .font(.title3)
                                    .foregroundColor(.white)  // ALWAYS white
                                Text(quality.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(quality.rawValue)
                            .listRowBackground(Constants.Colors.surface1)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Constants.Colors.accent)
                    .listRowBackground(Constants.Colors.surface1)
                } header: {
                    Text("Video")
                        .foregroundColor(.white)
                } footer: {
                    Text(selectedVideoQuality.description)
                        .foregroundColor(.secondary)
                }

                // Audio Quality
                Section {
                    Picker("Audio Quality", selection: $settingsManager.audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quality.rawValue)
                                    .font(.title3)
                                    .foregroundColor(.white)  // ALWAYS white
                                Text(quality.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(quality.rawValue)
                            .listRowBackground(Constants.Colors.surface1)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Constants.Colors.accent)
                    .listRowBackground(Constants.Colors.surface1)
                } header: {
                    Text("Audio")
                        .foregroundColor(.white)
                } footer: {
                    Text(selectedAudioQuality.description)
                        .foregroundColor(.secondary)
                }

                // Playback Behavior
                Section {
                    Toggle("Auto-Play Next Episode", isOn: $settingsManager.autoPlayNext)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Constants.Colors.accent)
                        .listRowBackground(Constants.Colors.surface1)

                    if settingsManager.autoPlayNext {
                        Picker("Countdown", selection: $settingsManager.autoPlayCountdown) {
                            Text("5 seconds").tag(5).foregroundColor(.white).listRowBackground(Constants.Colors.surface1)
                            Text("10 seconds").tag(10).foregroundColor(.white).listRowBackground(Constants.Colors.surface1)
                            Text("15 seconds").tag(15).foregroundColor(.white).listRowBackground(Constants.Colors.surface1)
                            Text("Off").tag(0).foregroundColor(.white).listRowBackground(Constants.Colors.surface1)
                        }
                        .foregroundColor(.white)  // ALWAYS white
                        .accentColor(Constants.Colors.accent)
                        .listRowBackground(Constants.Colors.surface1)
                    }

                    Toggle("Auto-Play Hero Trailers", isOn: $settingsManager.autoPlayTrailers)
                        .foregroundColor(.white)
                        .tint(Constants.Colors.accent)
                        .listRowBackground(Constants.Colors.surface1)
                } header: {
                    Text("Auto-Play")
                        .foregroundColor(.white)
                } footer: {
                    if settingsManager.autoPlayNext && settingsManager.autoPlayCountdown > 0 {
                        Text("Next episode will start after \(settingsManager.autoPlayCountdown) seconds. Hero trailers start muted on focus dwell.")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Hero trailers start muted on focus dwell.")
                            .foregroundColor(.secondary)
                    }
                }

                // Resume Behavior
                Section {
                    Picker("Resume Behavior", selection: $settingsManager.resumeBehavior) {
                        ForEach(ResumeBehavior.allCases) { behavior in
                            Text(behavior.rawValue).tag(behavior.rawValue)
                                .foregroundColor(.white)  // ALWAYS white
                                .listRowBackground(Constants.Colors.surface1)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Constants.Colors.accent)
                    .listRowBackground(Constants.Colors.surface1)
                } header: {
                    Text("Resume")
                        .foregroundColor(.white)
                } footer: {
                    Text("Choose how to handle partially watched content")
                        .foregroundColor(.secondary)
                }

                // Remember Preferences
                Section {
                    Toggle("Remember Audio Track", isOn: $settingsManager.rememberAudioTrack)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Constants.Colors.accent)
                        .listRowBackground(Constants.Colors.surface1)

                    Toggle("Remember Subtitle Track", isOn: $settingsManager.rememberSubtitleTrack)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Constants.Colors.accent)
                        .listRowBackground(Constants.Colors.surface1)
                } header: {
                    Text("Track Memory")
                        .foregroundColor(.white)
                } footer: {
                    Text("Remember your audio and subtitle preferences for each show")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Playback")
        .trackedPushedView()
        .onAppear {
            print("⚙️ PlaybackSettingsView appeared")
            print("📊 Current settings - Video: \(selectedVideoQuality.rawValue), Audio: \(selectedAudioQuality.rawValue), Auto-play: \(settingsManager.autoPlayNext)")
        }
    }
}

#Preview {
    NavigationStack {
        PlaybackSettingsView(settingsManager: SettingsManager())
    }
}
