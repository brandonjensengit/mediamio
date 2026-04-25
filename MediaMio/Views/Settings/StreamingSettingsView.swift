//
//  StreamingSettingsView.swift
//  MediaMio
//
//  Streaming + network settings: streaming mode, max bitrate, video
//  codec, transcoding allowance, low-bandwidth and local-network
//  preferences. Card-style layout matching `AccountSettingsView`.
//

import SwiftUI

private struct BitrateOption {
    let bps: Int
    let title: String
}

/// 10 explicit ladder rungs from mobile-class up to 4K Maximum.
/// Lives at file scope so the picker subtitle helper can reuse it.
private let bitrateOptions: [BitrateOption] = [
    .init(bps:   2_000_000, title: "2 Mbps · Mobile"),
    .init(bps:   5_000_000, title: "5 Mbps · SD"),
    .init(bps:  10_000_000, title: "10 Mbps · 720p"),
    .init(bps:  20_000_000, title: "20 Mbps · 1080p"),
    .init(bps:  40_000_000, title: "40 Mbps · 1080p HD"),
    .init(bps:  60_000_000, title: "60 Mbps · 1080p High"),
    .init(bps:  80_000_000, title: "80 Mbps · 1080p Remux"),
    .init(bps: 120_000_000, title: "120 Mbps · 4K (Recommended)"),
    .init(bps: 150_000_000, title: "150 Mbps · 4K High"),
    .init(bps: 200_000_000, title: "200 Mbps · 4K Maximum")
]

struct StreamingSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedStreamingMode: StreamingMode {
        StreamingMode(rawValue: settingsManager.streamingMode) ?? .auto
    }

    private var selectedCodec: VideoCodec {
        VideoCodec(rawValue: settingsManager.videoCodec) ?? .h264
    }

    private var bitrateValueLabel: String {
        bitrateOptions.first(where: { $0.bps == settingsManager.maxBitrate })?.title
            ?? "\(settingsManager.maxBitrate / 1_000_000) Mbps"
    }

    private var bitrateFooter: String {
        let mbps = Double(settingsManager.maxBitrate) / 1_000_000.0
        let prefix = "Current: \(String(format: "%.0f", mbps)) Mbps. "
        switch settingsManager.maxBitrate {
        case 0..<10_000_000:
            return prefix + "Very low — only for slow connections. Will look soft on the TV."
        case 10_000_000..<20_000_000:
            return prefix + "Low — fine for mobile / slow Wi-Fi. May look soft on the TV."
        case 20_000_000..<40_000_000:
            return prefix + "Good for 720p, marginal for 1080p."
        case 40_000_000..<80_000_000:
            return prefix + "Good for 1080p HD content."
        case 80_000_000..<120_000_000:
            return prefix + "Excellent for 1080p, good for 4K."
        default:
            return prefix + "Best quality for 4K and remux files."
        }
    }

    var body: some View {
        SettingsCardScreen(title: "Streaming") {
            SettingsSection("Mode", footer: selectedStreamingMode.description) {
                SettingsPickerNavRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Streaming Mode",
                    value: selectedStreamingMode.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Streaming Mode",
                        selection: $settingsManager.streamingMode,
                        options: StreamingMode.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection("Quality", footer: bitrateFooter) {
                SettingsPickerNavRow(
                    icon: "speedometer",
                    title: "Maximum Bitrate",
                    value: bitrateValueLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Maximum Bitrate",
                        footer: "Higher values look better on fast connections but can stutter on slow ones.",
                        selection: $settingsManager.maxBitrate,
                        options: bitrateOptions.map {
                            SettingsPickerOption(value: $0.bps, title: $0.title)
                        }
                    )
                }
            }

            SettingsSection("Video Codec", footer: selectedCodec.description) {
                SettingsPickerNavRow(
                    icon: "rectangle.stack.fill",
                    title: "Preferred Codec",
                    value: selectedCodec.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Preferred Codec",
                        selection: $settingsManager.videoCodec,
                        options: VideoCodec.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection(
                "Transcoding",
                footer: "When enabled, the server can convert video on the fly if your device can't play the original."
            ) {
                SettingsToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Allow Transcoding",
                    isOn: $settingsManager.allowTranscoding
                )
            }

            SettingsSection(
                "Network",
                footer: "Optimize for slow connections and prefer a local route to the server when one is available."
            ) {
                SettingsToggleRow(
                    icon: "wifi.exclamationmark",
                    title: "Low Bandwidth Mode",
                    isOn: $settingsManager.lowBandwidthMode
                )

                SettingsToggleRow(
                    icon: "house.fill",
                    title: "Prefer Local Network",
                    isOn: $settingsManager.preferLocalNetwork
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        StreamingSettingsView(settingsManager: SettingsManager())
    }
}
