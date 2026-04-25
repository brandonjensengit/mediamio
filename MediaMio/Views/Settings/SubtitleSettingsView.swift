//
//  SubtitleSettingsView.swift
//  MediaMio
//
//  Subtitle settings: mode, language, size, color, background, edge
//  style + a live preview that re-renders as you tweak each picker.
//  Card-style layout matching `AccountSettingsView`.
//

import SwiftUI

private struct LanguageOption {
    let code: String
    let name: String
}

private let subtitleLanguageOptions: [LanguageOption] = [
    .init(code: "none", name: "None"),
    .init(code: "eng",  name: "English"),
    .init(code: "spa",  name: "Spanish"),
    .init(code: "fra",  name: "French"),
    .init(code: "deu",  name: "German"),
    .init(code: "ita",  name: "Italian"),
    .init(code: "jpn",  name: "Japanese"),
    .init(code: "kor",  name: "Korean")
]

private struct ColorOption {
    let key: String
    let name: String
    let swatch: Color
}

private let subtitleColorOptions: [ColorOption] = [
    .init(key: "white",  name: "White",  swatch: .white),
    .init(key: "yellow", name: "Yellow", swatch: .yellow),
    .init(key: "cyan",   name: "Cyan",   swatch: .cyan),
    .init(key: "green",  name: "Green",  swatch: .green)
]

private struct BackgroundOption {
    let key: String
    let name: String
}

private let subtitleBackgroundOptions: [BackgroundOption] = [
    .init(key: "none",            name: "None"),
    .init(key: "semitransparent", name: "Semi-Transparent"),
    .init(key: "black",           name: "Black")
]

private struct EdgeStyleOption {
    let key: String
    let name: String
}

private let subtitleEdgeStyleOptions: [EdgeStyleOption] = [
    .init(key: "none",       name: "None"),
    .init(key: "dropShadow", name: "Drop Shadow"),
    .init(key: "outline",    name: "Outline"),
    .init(key: "raised",     name: "Raised")
]

struct SubtitleSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var selectedSize: SubtitleSize {
        SubtitleSize(rawValue: settingsManager.subtitleSize) ?? .medium
    }

    private var selectedMode: SubtitleMode {
        SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off
    }

    private var languageLabel: String {
        subtitleLanguageOptions.first(where: { $0.code == settingsManager.defaultSubtitleLanguage })?.name
            ?? settingsManager.defaultSubtitleLanguage.uppercased()
    }

    private var colorLabel: String {
        subtitleColorOptions.first(where: { $0.key == settingsManager.subtitleColor })?.name
            ?? settingsManager.subtitleColor.capitalized
    }

    private var backgroundLabel: String {
        subtitleBackgroundOptions.first(where: { $0.key == settingsManager.subtitleBackground })?.name
            ?? settingsManager.subtitleBackground.capitalized
    }

    private var edgeStyleLabel: String {
        subtitleEdgeStyleOptions.first(where: { $0.key == settingsManager.subtitleEdgeStyle })?.name
            ?? settingsManager.subtitleEdgeStyle.capitalized
    }

    var body: some View {
        SettingsCardScreen(title: "Subtitles") {
            SettingsSection("Mode", footer: selectedMode.description) {
                SettingsPickerNavRow(
                    icon: "captions.bubble.fill",
                    title: "Subtitle Mode",
                    value: selectedMode.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Subtitle Mode",
                        selection: $settingsManager.subtitleMode,
                        options: SubtitleMode.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue, subtitle: $0.description)
                        }
                    )
                }
            }

            SettingsSection("Language") {
                SettingsPickerNavRow(
                    icon: "globe",
                    title: "Default Language",
                    value: languageLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Default Language",
                        selection: $settingsManager.defaultSubtitleLanguage,
                        options: subtitleLanguageOptions.map {
                            SettingsPickerOption(value: $0.code, title: $0.name)
                        }
                    )
                }
            }

            SettingsSection("Appearance") {
                SettingsPickerNavRow(
                    icon: "textformat.size",
                    title: "Size",
                    value: selectedSize.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Size",
                        selection: $settingsManager.subtitleSize,
                        options: SubtitleSize.allCases.map {
                            SettingsPickerOption(value: $0.rawValue, title: $0.rawValue)
                        }
                    )
                }

                SettingsPickerNavRow(
                    icon: "paintpalette.fill",
                    title: "Color",
                    value: colorLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Color",
                        selection: $settingsManager.subtitleColor,
                        options: subtitleColorOptions.map { option in
                            SettingsPickerOption(
                                value: option.key,
                                title: option.name,
                                leading: AnyView(
                                    Circle()
                                        .fill(option.swatch)
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                                )
                            )
                        }
                    )
                }

                SettingsPickerNavRow(
                    icon: "rectangle.fill",
                    title: "Background",
                    value: backgroundLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Background",
                        selection: $settingsManager.subtitleBackground,
                        options: subtitleBackgroundOptions.map {
                            SettingsPickerOption(value: $0.key, title: $0.name)
                        }
                    )
                }

                SettingsPickerNavRow(
                    icon: "scribble",
                    title: "Edge Style",
                    value: edgeStyleLabel
                ) {
                    SettingsOptionPickerView(
                        title: "Edge Style",
                        selection: $settingsManager.subtitleEdgeStyle,
                        options: subtitleEdgeStyleOptions.map {
                            SettingsPickerOption(value: $0.key, title: $0.name)
                        }
                    )
                }
            }

            SettingsSection("Preview", footer: "How your subtitles will look during playback.") {
                SubtitlePreview(
                    size: selectedSize,
                    color: settingsManager.subtitleColor,
                    background: settingsManager.subtitleBackground,
                    edgeStyle: settingsManager.subtitleEdgeStyle
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
            }
        }
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
            Color.black
                .overlay(
                    Image(systemName: "tv")
                        .font(.system(size: 120))
                        .foregroundColor(.gray.opacity(0.3))
                )

            VStack {
                Spacer()

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
