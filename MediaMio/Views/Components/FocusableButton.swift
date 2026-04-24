//
//  FocusableButton.swift
//  MediaMio
//
//  Thin wrapper over `CTAButton`. Kept as a compatibility alias so that
//  the 9+ auth / empty-state / error-retry callers don't have to change.
//  New code should use `CTAButton` directly.
//

import SwiftUI

struct FocusableButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle

    enum ButtonStyle {
        case primary
        case secondary
        case destructive

        fileprivate var ctaStyle: CTAButton.Style {
            switch self {
            case .primary: return .primary
            case .secondary: return .secondary
            case .destructive: return .destructive
            }
        }
    }

    init(
        title: String,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        CTAButton(title: title, style: style.ctaStyle, action: action)
    }
}

#Preview {
    VStack(spacing: 20) {
        FocusableButton(title: "Sign In", style: .primary) {}
        FocusableButton(title: "Cancel", style: .secondary) {}
        FocusableButton(title: "Sign Out", style: .destructive) {}
    }
    .padding()
    .background(Constants.Colors.background)
}
