//
//  FocusableButton.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct FocusableButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle

    @FocusState private var isFocused: Bool
    @Environment(\.isFocused) private var envFocused

    enum ButtonStyle {
        case primary
        case secondary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary: return Constants.Colors.primary
            case .secondary: return Constants.Colors.cardBackground
            case .destructive: return .red.opacity(0.8)
            }
        }

        var foregroundColor: Color {
            return .white
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
        Button(action: action) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.UI.buttonHeight)
                .background(style.backgroundColor)
                .cornerRadius(Constants.UI.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(Color.clear, lineWidth: 0)
                )
                .scaleEffect(envFocused ? Constants.UI.focusScale : Constants.UI.normalScale)
                .shadow(
                    color: envFocused ? .white.opacity(0.4) : .clear,
                    radius: Constants.UI.focusShadowRadius
                )
                .animation(.easeInOut(duration: Constants.UI.animationDuration), value: envFocused)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        FocusableButton(title: "Sign In", style: .primary) {
            print("Primary button tapped")
        }

        FocusableButton(title: "Cancel", style: .secondary) {
            print("Secondary button tapped")
        }

        FocusableButton(title: "Sign Out", style: .destructive) {
            print("Destructive button tapped")
        }
    }
    .padding()
    .background(Color.black)
}
