//
//  SkipSettingsView.swift
//  MediaMio
//
//  Auto-skip settings: intros, credits, recaps + global skip behavior.
//  Card-style layout matching `AccountSettingsView`.
//

import SwiftUI

struct SkipSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedSkipBehavior: SkipBehavior {
        SkipBehavior(rawValue: settingsManager.skipBehavior) ?? .buttonWithDelay
    }

    private var introCountdownLabel: String {
        switch settingsManager.skipIntroCountdown {
        case 0: return "Instantly"
        default: return "\(settingsManager.skipIntroCountdown) seconds"
        }
    }

    private var creditsCountdownLabel: String {
        "\(settingsManager.skipCreditsCountdown) seconds"
    }

    var body: some View {
        SettingsCardScreen(title: "Auto-Skip") {
            SettingsSection("Intros", footer: introsFooter) {
                SettingsToggleRow(
                    icon: "forward.fill",
                    title: "Auto-Skip Intros",
                    isOn: $settingsManager.autoSkipIntros
                )

                SettingsToggleRow(
                    icon: "rectangle.badge.checkmark",
                    title: "Show Skip Button",
                    isOn: $settingsManager.showSkipIntroButton,
                    isEnabled: settingsManager.autoSkipIntros
                )

                if settingsManager.autoSkipIntros {
                    SettingsPickerNavRow(
                        icon: "timer",
                        title: "Skip After",
                        value: introCountdownLabel
                    ) {
                        SettingsOptionPickerView(
                            title: "Skip After",
                            selection: $settingsManager.skipIntroCountdown,
                            options: [
                                SettingsPickerOption(value: 0, title: "Instantly"),
                                SettingsPickerOption(value: 3, title: "3 seconds"),
                                SettingsPickerOption(value: 5, title: "5 seconds")
                            ]
                        )
                    }
                }
            }

            SettingsSection("Credits", footer: creditsFooter) {
                SettingsToggleRow(
                    icon: "forward.end.fill",
                    title: "Auto-Skip Credits",
                    isOn: $settingsManager.autoSkipCredits
                )

                SettingsToggleRow(
                    icon: "rectangle.badge.checkmark",
                    title: "Show Skip Credits Button",
                    isOn: $settingsManager.showSkipCreditsButton
                )

                SettingsToggleRow(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "Show Next Episode Overlay",
                    isOn: $settingsManager.showNextEpisodeOverlay,
                    isEnabled: settingsManager.autoSkipCredits
                )

                if settingsManager.autoSkipCredits {
                    SettingsPickerNavRow(
                        icon: "timer",
                        title: "Start Next Episode After",
                        value: creditsCountdownLabel
                    ) {
                        SettingsOptionPickerView(
                            title: "Start Next Episode After",
                            selection: $settingsManager.skipCreditsCountdown,
                            options: [
                                SettingsPickerOption(value: 5,  title: "5 seconds"),
                                SettingsPickerOption(value: 10, title: "10 seconds"),
                                SettingsPickerOption(value: 15, title: "15 seconds"),
                                SettingsPickerOption(value: 20, title: "20 seconds")
                            ]
                        )
                    }
                }
            }

            SettingsSection("Recaps", footer: "Skip 'Previously on…' segments at the start of episodes.") {
                SettingsToggleRow(
                    icon: "backward.fill",
                    title: "Auto-Skip Recaps",
                    isOn: $settingsManager.autoSkipRecaps
                )

                SettingsToggleRow(
                    icon: "rectangle.badge.checkmark",
                    title: "Show Skip Button",
                    isOn: $settingsManager.showSkipRecapButton,
                    isEnabled: settingsManager.autoSkipRecaps
                )
            }

            SettingsSection("General Behavior", footer: selectedSkipBehavior.description) {
                SettingsPickerNavRow(
                    icon: "slider.horizontal.3",
                    title: "Skip Behavior",
                    value: selectedSkipBehavior.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Skip Behavior",
                        selection: $settingsManager.skipBehavior,
                        options: SkipBehavior.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection {
                InfoNoteRow(
                    text: "Skip markers are provided by your Jellyfin server and may not be available for all content. Accuracy depends on server-side detection."
                )
            }
        }
    }

    private var introsFooter: String {
        settingsManager.autoSkipIntros
            ? "Opening credits will be skipped automatically."
            : "A 'Skip Intro' button appears during opening credits."
    }

    private var creditsFooter: String {
        settingsManager.autoSkipCredits
            ? "Next episode starts automatically during end credits."
            : "A 'Next Episode' button appears during end credits."
    }
}

/// Read-only informational card with a leading info glyph. Used for the
/// "skip markers come from the server" note here, and reusable wherever
/// a non-actionable hint belongs in the card stack.
struct InfoNoteRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }
}

#Preview {
    NavigationStack {
        SkipSettingsView(settingsManager: SettingsManager())
    }
}
