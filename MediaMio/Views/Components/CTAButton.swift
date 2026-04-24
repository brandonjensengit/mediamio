//
//  CTAButton.swift
//  MediaMio
//
//  Canonical full-width call-to-action button for auth flows, empty-state
//  actions, error retries, and destructive confirmations.
//  Constraint: chrome focus tier only. For hero Play/Resume use
//  `HeroBannerButton` (content tier, larger lift + focus-change callback).
//

import SwiftUI

struct CTAButton: View {
    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary: return Constants.Colors.accent
            case .secondary: return Constants.Colors.surface2
            case .destructive: return Color(hex: "a33a2e").opacity(0.9)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return Constants.Colors.background
            case .secondary, .destructive: return .white
            }
        }
    }

    init(
        title: String,
        icon: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(style.backgroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .buttonStyle(.plain)
        .chromeFocus()
    }
}

#Preview {
    VStack(spacing: 20) {
        CTAButton(title: "Sign In", style: .primary) {}
        CTAButton(title: "Use Quick Connect", icon: "qrcode", style: .secondary) {}
        CTAButton(title: "Sign Out", style: .destructive) {}
    }
    .padding(40)
    .background(Constants.Colors.background)
}
