//
//  SettingsRowWithFocus.swift
//  MediaMio
//
//  Created by Claude Code
//  Fix for invisible text on white background when focused
//

import SwiftUI

/// Settings row component with proper focus visibility
/// Ensures text is always visible (white text on colored background when focused)
struct SettingsRowWithFocus: View {
    let title: String
    let value: String?
    let subtitle: String?

    @Environment(\.isFocused) private var isFocused

    init(title: String, value: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)  // ALWAYS white

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let value = value {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)  // ALWAYS white
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Color(hex: "667eea").opacity(0.2) : Color.clear)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        NavigationLink {
            Text("Destination")
        } label: {
            SettingsRowWithFocus(
                title: "Preferred Codec",
                value: "H.264/AVC",
                subtitle: "Universal compatibility, larger file sizes"
            )
        }
        .buttonStyle(.plain)

        NavigationLink {
            Text("Destination")
        } label: {
            SettingsRowWithFocus(
                title: "Video Quality",
                value: "1080p Full HD"
            )
        }
        .buttonStyle(.plain)

        NavigationLink {
            Text("Destination")
        } label: {
            SettingsRowWithFocus(
                title: "Subtitles"
            )
        }
        .buttonStyle(.plain)
    }
    .padding()
    .background(Color.black)
}
