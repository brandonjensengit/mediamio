//
//  PlaybackSettingsView.swift
//  MediaMio
//
//  Playback settings: video / audio quality, auto-play, resume, track
//  memory. Card-style layout matching `AccountSettingsView` — pickers
//  push a generic option-picker sub-screen, toggles live inline.
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

    private var countdownLabel: String {
        switch settingsManager.autoPlayCountdown {
        case 0: return "Off"
        default: return "\(settingsManager.autoPlayCountdown) seconds"
        }
    }

    var body: some View {
        SettingsCardScreen(title: "Playback") {
            SettingsSection("Video", footer: selectedVideoQuality.description) {
                SettingsPickerNavRow(
                    icon: "tv.fill",
                    title: "Video Quality",
                    value: selectedVideoQuality.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Video Quality",
                        selection: $settingsManager.videoQuality,
                        options: VideoQuality.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection("Audio", footer: selectedAudioQuality.description) {
                SettingsPickerNavRow(
                    icon: "speaker.wave.2.fill",
                    title: "Audio Quality",
                    value: selectedAudioQuality.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Audio Quality",
                        selection: $settingsManager.audioQuality,
                        options: AudioQuality.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection("Auto-Play", footer: autoPlayFooter) {
                SettingsToggleRow(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "Auto-Play Next Episode",
                    isOn: $settingsManager.autoPlayNext
                )

                if settingsManager.autoPlayNext {
                    SettingsPickerNavRow(
                        icon: "timer",
                        title: "Countdown",
                        value: countdownLabel
                    ) {
                        SettingsOptionPickerView(
                            title: "Countdown",
                            footer: "How long the next-episode prompt waits before auto-starting playback.",
                            selection: $settingsManager.autoPlayCountdown,
                            options: [
                                SettingsPickerOption(value: 5,  title: "5 seconds"),
                                SettingsPickerOption(value: 10, title: "10 seconds"),
                                SettingsPickerOption(value: 15, title: "15 seconds"),
                                SettingsPickerOption(value: 0,  title: "Off",
                                                     subtitle: "Show the prompt without a countdown.")
                            ]
                        )
                    }
                }

                SettingsToggleRow(
                    icon: "sparkles.tv.fill",
                    title: "Auto-Play Hero Trailers",
                    subtitle: "Hero trailers start muted on focus dwell.",
                    isOn: $settingsManager.autoPlayTrailers
                )
            }

            SettingsSection("Resume", footer: "Choose how partially watched content is handled when you reopen it.") {
                SettingsPickerNavRow(
                    icon: "play.circle.fill",
                    title: "Resume Behavior",
                    value: selectedResumeBehavior.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Resume Behavior",
                        selection: $settingsManager.resumeBehavior,
                        options: ResumeBehavior.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue)
                        }
                    )
                }
            }

            SettingsSection("Track Memory", footer: "Remember the audio and subtitle tracks you pick on each show.") {
                SettingsToggleRow(
                    icon: "waveform",
                    title: "Remember Audio Track",
                    isOn: $settingsManager.rememberAudioTrack
                )

                SettingsToggleRow(
                    icon: "captions.bubble.fill",
                    title: "Remember Subtitle Track",
                    isOn: $settingsManager.rememberSubtitleTrack
                )
            }
        }
    }

    private var autoPlayFooter: String {
        if settingsManager.autoPlayNext && settingsManager.autoPlayCountdown > 0 {
            return "Next episode starts after \(settingsManager.autoPlayCountdown) seconds."
        }
        if settingsManager.autoPlayNext {
            return "Next episode is queued without a countdown."
        }
        return "A 'Play Next' prompt will appear at the end of each episode."
    }
}

#Preview {
    NavigationStack {
        PlaybackSettingsView(settingsManager: SettingsManager())
    }
}
