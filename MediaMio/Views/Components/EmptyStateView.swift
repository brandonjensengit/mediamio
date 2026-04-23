//
//  EmptyStateView.swift
//  MediaMio
//
//  Shared empty-state presentation used wherever a content area has
//  nothing to show (library empty, search idle, search returned zero
//  results, etc.). Replaces five bespoke empty-state views that had
//  drifted in font sizes, icon opacity, and layout.
//  Constraint: never routes to any navigation or data source — it is a
//  pure presentation component. An optional primary action can be
//  attached by the caller (e.g. a retry or "Try different keywords").
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String?
    let iconOpacity: Double
    let action: Action?

    struct Action {
        let title: String
        let handler: () -> Void
    }

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        iconOpacity: Double = 0.5,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.iconOpacity = iconOpacity
        self.action = action
    }

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(iconOpacity))

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let message = message {
                    Text(message)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 600)
                }
            }

            if let action = action {
                FocusableButton(title: action.title, style: .primary) {
                    action.handler()
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview("Empty library") {
    EmptyStateView(
        systemImage: "film.stack",
        title: "No Content in Movies",
        message: "Add some media to this library in Jellyfin"
    )
    .frame(width: 1920, height: 1080)
    .background(Color.black)
}

#Preview("Search idle") {
    EmptyStateView(
        systemImage: "magnifyingglass",
        title: "Search Your Library",
        message: "Find movies, TV shows, and more"
    )
    .frame(width: 1920, height: 1080)
    .background(Color.black)
}
