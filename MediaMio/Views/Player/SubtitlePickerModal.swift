//
//  SubtitlePickerModal.swift
//  MediaMio
//
//  Subtitle selection modal for video player
//

import SwiftUI

struct SubtitlePickerModal: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Text("Subtitles")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 60)
                .padding(.top, 60)

                // Subtitle Options
                VStack(spacing: 16) {
                    // Off option
                    SubtitleOptionRow(
                        title: "Off",
                        isSelected: viewModel.selectedSubtitleIndex == nil
                    ) {
                        viewModel.selectSubtitle(at: nil)
                        dismiss()
                    }
                    .focused($focusedIndex, equals: -1)

                    // Available subtitle tracks
                    ForEach(viewModel.availableSubtitles) { track in
                        SubtitleOptionRow(
                            title: track.displayName,
                            language: track.languageCode,
                            isSelected: viewModel.selectedSubtitleIndex == track.index
                        ) {
                            viewModel.selectSubtitle(at: track.index)
                            dismiss()
                        }
                        .focused($focusedIndex, equals: track.index)
                    }
                }
                .padding(.horizontal, 60)

                Spacer()
            }
        }
        .onAppear {
            // Focus current selection or "Off"
            focusedIndex = viewModel.selectedSubtitleIndex ?? -1
        }
    }
}

// MARK: - Subtitle Option Row

struct SubtitleOptionRow: View {
    let title: String
    var language: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Title and language
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(.white)

                    if let language = language {
                        Text(language.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.3)
        } else if isFocused {
            return Color.white.opacity(0.15)
        } else {
            return Color.white.opacity(0.05)
        }
    }

    private var borderColor: Color {
        if isFocused {
            return .white
        } else if isSelected {
            return .accentColor
        } else {
            return .clear
        }
    }
}
