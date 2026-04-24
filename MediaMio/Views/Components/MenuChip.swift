//
//  MenuChip.swift
//  MediaMio
//
//  Shared pill component for toolbar actions, sort menus, filter chips.
//  Constraint: never competes with content focus — always uses the chrome
//  focus tier (subtle lift, no glow). If you find yourself reaching for
//  a larger lift or a shadow here, you want `CTAButton` or
//  `HeroBannerButton` instead.
//

import SwiftUI

/// Compact rounded-rect pill: optional leading icon · text · optional trailing icon.
/// Fills surface1 by default so it reads as chrome against the page background.
struct MenuChip: View {
    let title: String
    let leadingIcon: String?
    let trailingIcon: String?
    let action: () -> Void

    init(
        title: String,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                }
                Text(title)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Constants.Colors.surface1)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .chromeFocus()
    }
}

#Preview {
    HStack(spacing: 16) {
        MenuChip(title: "Sort: Recently Added", leadingIcon: "arrow.up.arrow.down", trailingIcon: "chevron.down") {}
        MenuChip(title: "Search", leadingIcon: "magnifyingglass") {}
        MenuChip(title: "Filter") {}
    }
    .padding()
    .background(Constants.Colors.background)
}
