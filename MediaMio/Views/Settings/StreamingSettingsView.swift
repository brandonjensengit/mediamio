//
//  StreamingSettingsView.swift
//  MediaMio
//
//  Streaming settings: bitrate, quality, network options
//

import SwiftUI

struct StreamingSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedStreamingMode: StreamingMode {
        StreamingMode(rawValue: settingsManager.streamingMode) ?? .auto
    }

    private var bitrateDescription: String {
        let mbps = Double(settingsManager.maxBitrate) / 1_000_000.0
        let current = "Current: \(String(format: "%.0f", mbps)) Mbps. "

        switch settingsManager.maxBitrate {
        case 0..<10_000_000:
            return current + "⚠️ Very Low - Only for slow connections. May be blurry."
        case 10_000_000..<20_000_000:
            return current + "⚠️ Low - For mobile/slow WiFi. May be blurry on TV."
        case 20_000_000..<40_000_000:
            return current + "📱 Good - Fine for 720p, may be blurry for 1080p."
        case 40_000_000..<80_000_000:
            return current + "✅ High - Good for 1080p HD content."
        case 80_000_000..<120_000_000:
            return current + "✅ Very High - Excellent for 1080p, good for 4K."
        default:
            return current + "🎬 Maximum - Best quality for 4K and remux files."
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                // Streaming Mode
                Section {
                    Picker("Streaming Mode", selection: $settingsManager.streamingMode) {
                        ForEach(StreamingMode.allCases) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue)
                                    .font(.title3)
                                    .foregroundColor(.white)  // ALWAYS white
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode.rawValue)
                            .listRowBackground(Color.black.opacity(0.3))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Mode")
                        .foregroundColor(.white)
                } footer: {
                    Text(selectedStreamingMode.description)
                        .foregroundColor(.secondary)
                }

                // Bitrate Settings
                Section {
                    Picker("Maximum Bitrate", selection: $settingsManager.maxBitrate) {
                        Text("2 Mbps - Mobile").tag(2_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("5 Mbps - SD").tag(5_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("10 Mbps - 720p").tag(10_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("20 Mbps - 1080p").tag(20_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("40 Mbps - 1080p HD").tag(40_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("60 Mbps - 1080p High").tag(60_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("80 Mbps - 1080p Remux").tag(80_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("120 Mbps - 4K (Recommended)").tag(120_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("150 Mbps - 4K High").tag(150_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("200 Mbps - 4K Maximum").tag(200_000_000).foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Quality")
                        .foregroundColor(.white)
                } footer: {
                    Text(bitrateDescription)
                        .foregroundColor(.secondary)
                }

                // Video Codec
                Section {
                    Picker("Preferred Codec", selection: $settingsManager.videoCodec) {
                        ForEach(VideoCodec.allCases) { codec in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(codec.rawValue)
                                    .foregroundColor(.white)  // ALWAYS white
                                Text(codec.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(codec.rawValue)
                            .listRowBackground(Color.black.opacity(0.3))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Video Codec")
                        .foregroundColor(.white)
                }

                // Transcoding
                Section {
                    Toggle("Allow Transcoding", isOn: $settingsManager.allowTranscoding)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Transcoding")
                        .foregroundColor(.white)
                } footer: {
                    Text("When enabled, server can convert video format if needed")
                        .foregroundColor(.secondary)
                }

                // Network
                Section {
                    Toggle("Low Bandwidth Mode", isOn: $settingsManager.lowBandwidthMode)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .listRowBackground(Color.clear)

                    Toggle("Prefer Local Network", isOn: $settingsManager.preferLocalNetwork)
                        .foregroundColor(.white)  // ALWAYS white
                        .tint(Color(hex: "667eea"))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Network")
                        .foregroundColor(.white)
                } footer: {
                    Text("Optimize streaming for slow connections and prefer local network when available")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Streaming & Network")
        .onAppear {
            print("⚙️ StreamingSettingsView appeared")
            print("📊 Current settings - Bitrate: \(settingsManager.bitrateDisplay), Mode: \(selectedStreamingMode.rawValue), Transcoding: \(settingsManager.allowTranscoding)")
        }
    }
}

#Preview {
    NavigationStack {
        StreamingSettingsView(settingsManager: SettingsManager())
    }
}
