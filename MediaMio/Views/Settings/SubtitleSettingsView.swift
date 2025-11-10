//
//  SubtitleSettingsView.swift
//  MediaMio
//
//  Subtitle settings: language, appearance, live preview
//

import SwiftUI

struct SubtitleSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedSize: SubtitleSize {
        SubtitleSize(rawValue: settingsManager.subtitleSize) ?? .medium
    }

    private var selectedMode: SubtitleMode {
        SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Form {
                // Subtitle Mode
                Section {
                    Picker("Subtitle Mode", selection: $settingsManager.subtitleMode) {
                        ForEach(SubtitleMode.allCases) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue)
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
                    Text(selectedMode.description)
                        .foregroundColor(.secondary)
                }

                // Default Language
                Section {
                    Picker("Default Language", selection: $settingsManager.defaultSubtitleLanguage) {
                        Text("None").tag("none")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("English").tag("eng")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Spanish").tag("spa")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("French").tag("fra")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("German").tag("deu")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Italian").tag("ita")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Japanese").tag("jpn")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Korean").tag("kor")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Language")
                        .foregroundColor(.white)
                }

                // Appearance
                Section {
                    Picker("Size", selection: $settingsManager.subtitleSize) {
                        ForEach(SubtitleSize.allCases) { size in
                            Text(size.rawValue).tag(size.rawValue)
                                .foregroundColor(.white)  // ALWAYS white
                                .listRowBackground(Color.black.opacity(0.3))
                        }
                    }
                    .pickerStyle(.segmented)
                    .foregroundColor(.white)  // ALWAYS white

                    Picker("Color", selection: $settingsManager.subtitleColor) {
                        HStack {
                            Circle().fill(.white).frame(width: 20, height: 20)
                            Text("White").foregroundColor(.white)
                        }
                        .tag("white")
                        .listRowBackground(Color.black.opacity(0.3))

                        HStack {
                            Circle().fill(.yellow).frame(width: 20, height: 20)
                            Text("Yellow").foregroundColor(.white)
                        }
                        .tag("yellow")
                        .listRowBackground(Color.black.opacity(0.3))

                        HStack {
                            Circle().fill(.cyan).frame(width: 20, height: 20)
                            Text("Cyan").foregroundColor(.white)
                        }
                        .tag("cyan")
                        .listRowBackground(Color.black.opacity(0.3))

                        HStack {
                            Circle().fill(.green).frame(width: 20, height: 20)
                            Text("Green").foregroundColor(.white)
                        }
                        .tag("green")
                        .listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))

                    .listRowBackground(Color.black.opacity(0.3))
                    Picker("Background", selection: $settingsManager.subtitleBackground) {
                        Text("None").tag("none")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Semi-Transparent").tag("semitransparent")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Black").tag("black")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))

                    .listRowBackground(Color.black.opacity(0.3))
                    Picker("Edge Style", selection: $settingsManager.subtitleEdgeStyle) {
                        Text("None").tag("none")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Drop Shadow").tag("dropShadow")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Outline").tag("outline")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                        Text("Raised").tag("raised")
                            .foregroundColor(.white).listRowBackground(Color.black.opacity(0.3))
                    }
                    .pickerStyle(.navigationLink)
                    .foregroundColor(.white)  // ALWAYS white
                    .accentColor(Color(hex: "667eea"))
                    .listRowBackground(Color.black.opacity(0.3))
                } header: {
                    Text("Appearance")
                        .foregroundColor(.white)
                }

                // Live Preview
                Section {
                    SubtitlePreview(
                        size: selectedSize,
                        color: settingsManager.subtitleColor,
                        background: settingsManager.subtitleBackground,
                        edgeStyle: settingsManager.subtitleEdgeStyle
                    )
                    .frame(height: 250)
                    .cornerRadius(12)
                } header: {
                    Text("Preview")
                        .foregroundColor(.white)
                } footer: {
                    Text("This is how your subtitles will appear during playback")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Subtitles")
    }
}

// MARK: - Subtitle Preview

struct SubtitlePreview: View {
    let size: SubtitleSize
    let color: String
    let background: String
    let edgeStyle: String

    var body: some View {
        ZStack {
            // Background scene
            Color.black
                .overlay(
                    Image(systemName: "tv")
                        .font(.system(size: 120))
                        .foregroundColor(.gray.opacity(0.3))
                )

            VStack {
                Spacer()

                // Sample subtitle text
                Text("This is how your subtitles will look")
                    .font(.system(size: 28 * size.scaleFactor, weight: .semibold))
                    .foregroundColor(colorFromString(color))
                    .padding(.horizontal, 50)
                    .padding(.vertical, 16)
                    .background(backgroundFromString(background))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(edgeStyle == "dropShadow" ? 0.8 : 0), radius: 4, x: 2, y: 2)
                    .overlay(
                        edgeStyle == "outline" ?
                        Text("This is how your subtitles will look")
                            .font(.system(size: 28 * size.scaleFactor, weight: .semibold))
                            .foregroundColor(.clear)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 16)
                            .background(Color.clear)
                            .overlay(
                                Text("This is how your subtitles will look")
                                    .font(.system(size: 28 * size.scaleFactor, weight: .semibold))
                                    .stroke(color: .black, lineWidth: 3)
                            )
                        : nil
                    )
                    .padding(.bottom, 50)
            }
        }
    }

    func colorFromString(_ string: String) -> Color {
        switch string {
        case "white": return .white
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "green": return .green
        default: return .white
        }
    }

    func backgroundFromString(_ string: String) -> Color {
        switch string {
        case "none": return .clear
        case "semitransparent": return .black.opacity(0.7)
        case "black": return .black
        default: return .clear
        }
    }
}

// MARK: - Text Stroke Extension

extension Text {
    func stroke(color: Color, lineWidth: CGFloat) -> some View {
        self.overlay(
            self
                .offset(x: -lineWidth, y: -lineWidth)
                .foregroundColor(color)
        )
        .overlay(
            self
                .offset(x: lineWidth, y: -lineWidth)
                .foregroundColor(color)
        )
        .overlay(
            self
                .offset(x: -lineWidth, y: lineWidth)
                .foregroundColor(color)
        )
        .overlay(
            self
                .offset(x: lineWidth, y: lineWidth)
                .foregroundColor(color)
        )
    }
}

#Preview {
    NavigationStack {
        SubtitleSettingsView(settingsManager: SettingsManager())
    }
}
