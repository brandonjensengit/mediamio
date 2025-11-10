//
//  BitratePickerModal.swift
//  MediaMio
//
//  Bitrate selection modal for video player overlay
//

import SwiftUI

struct BitratePickerModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsManager: SettingsManager
    @FocusState private var focusedBitrate: Int?

    // Bitrate options in bps
    private let bitrateOptions: [(mbps: String, bps: Int, description: String)] = [
        ("2", 2_000_000, "Mobile"),
        ("5", 5_000_000, "SD Quality"),
        ("10", 10_000_000, "720p HD"),
        ("20", 20_000_000, "1080p"),
        ("40", 40_000_000, "1080p HD"),
        ("60", 60_000_000, "1080p High"),
        ("80", 80_000_000, "1080p Remux"),
        ("120", 120_000_000, "4K"),
        ("150", 150_000_000, "4K High"),
        ("200", 200_000_000, "4K Maximum")
    ]

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Text("Video Quality")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Done button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .focused($focusedBitrate, equals: -1)
                }
                .padding(.horizontal, 60)
                .padding(.top, 60)

                // Bitrate options
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(bitrateOptions.enumerated()), id: \.offset) { index, option in
                            BitrateOptionRow(
                                mbps: option.mbps,
                                description: option.description,
                                isSelected: settingsManager.maxBitrate == option.bps,
                                action: {
                                    settingsManager.maxBitrate = option.bps
                                    print("📊 Bitrate changed to: \(option.mbps) Mbps")
                                }
                            )
                            .focused($focusedBitrate, equals: index)
                        }
                    }
                    .padding(.horizontal, 60)
                }

                Spacer()
            }
        }
        .onAppear {
            // Focus the currently selected bitrate or the first option
            if let selectedIndex = bitrateOptions.firstIndex(where: { $0.bps == settingsManager.maxBitrate }) {
                focusedBitrate = selectedIndex
            } else {
                focusedBitrate = 0
            }
        }
    }
}

// MARK: - Bitrate Option Row

struct BitrateOptionRow: View {
    let mbps: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.3))
                    .frame(width: 40)

                // Bitrate info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(mbps) Mbps")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .background(isFocused ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BitratePickerModal(settingsManager: SettingsManager())
}
