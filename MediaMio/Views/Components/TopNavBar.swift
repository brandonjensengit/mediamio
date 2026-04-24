//
//  TopNavBar.swift
//  MediaMio
//
//  Custom top navigation bar for the main app surface. Replaces the stock
//  tvOS `TabView { .tabItem { ... } }` chrome with a branded layout:
//  logo (leading) · tab chips (center, with matched-geometry underline) ·
//  user chip (trailing). Drives `NavigationManager.selectedTab`.
//
//  Focus: wrapped in `.focusSection()` so the tvOS remote treats the whole
//  bar as one sticky focus container — up-press from content returns here,
//  down-press exits into content predictably.
//

import SwiftUI

struct TopNavBar: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var authService: AuthenticationService
    @Namespace private var underlineNamespace

    var body: some View {
        HStack(spacing: 0) {
            branding
            Spacer()
            tabChips
            Spacer()
            userChip
        }
        .padding(.horizontal, 80)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .focusSection()
    }

    // MARK: - Branding (leading)

    private var branding: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .frame(minWidth: 180, alignment: .leading)
    }

    // MARK: - Tab chips (center)

    private var tabChips: some View {
        HStack(spacing: 44) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TopNavTabChip(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: underlineNamespace,
                    action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
    }

    // MARK: - User chip (trailing)

    private var userChip: some View {
        HStack(spacing: 14) {
            if let name = authService.currentSession?.user.name {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.75))

                ZStack {
                    Circle()
                        .fill(Constants.Colors.accent.opacity(0.9))
                        .frame(width: 48, height: 48)

                    Text(String(name.prefix(1)).uppercased())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.background)
                }
            }
        }
        .frame(minWidth: 180, alignment: .trailing)
    }
}

// MARK: - Tab chip

private struct TopNavTabChip: View {
    let tab: Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(tab.title)
                    .font(.title2)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                // Matched-geometry underline: only the selected chip renders
                // the bar; SwiftUI animates the slide between chips.
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.accent)
                            .frame(height: 4)
                            .matchedGeometryEffect(id: "topNavUnderline", in: namespace)
                    } else {
                        Color.clear.frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .chromeFocus()
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isFocused {
            return .white.opacity(0.9)
        } else {
            return .white.opacity(0.55)
        }
    }
}
