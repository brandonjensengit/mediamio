//
//  SidebarView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct SidebarView: View {
    @Binding var isVisible: Bool
    let onMenuItemSelected: (MenuItem) -> Void
    @State private var focusedItems: Set<MenuItem> = []

    var body: some View {
        // Sidebar menu
        VStack(alignment: .leading, spacing: 0) {
            // App branding
            VStack(alignment: .leading, spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                Image("LogoText")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
            }
            .padding(.horizontal, 40)
            .padding(.top, 60)
            .padding(.bottom, 40)

            // Menu items
            VStack(alignment: .leading, spacing: 10) {
                ForEach(MenuItem.allCases) { item in
                    SidebarMenuButton(
                        item: item,
                        onSelect: {
                            onMenuItemSelected(item)
                        },
                        onFocusChange: { isFocused in
                            if isFocused {
                                focusedItems.insert(item)
                                isVisible = true
                            } else {
                                focusedItems.remove(item)
                                if focusedItems.isEmpty {
                                    // When all items lose focus, hide sidebar
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if focusedItems.isEmpty {
                                            isVisible = false
                                        }
                                    }
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(width: 350)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - Sidebar Menu Button

struct SidebarMenuButton: View {
    let item: MenuItem
    let onSelect: () -> Void
    let onFocusChange: (Bool) -> Void
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 20) {
                Image(systemName: item.icon)
                    .font(.title2)
                    .frame(width: 40)

                Text(item.title)
                    .font(.title3)
                    .fontWeight(isFocused ? .bold : .semibold)
            }
            .foregroundColor(isFocused ? .white : .white.opacity(0.7))
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color.white.opacity(0.2) : Color.clear)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .onChange(of: isFocused) { focused in
            onFocusChange(focused)
        }
    }
}

// MARK: - Menu Item

enum MenuItem: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case search = "Search"
    case movies = "Movies"
    case tvShows = "TV Shows"
    case favorites = "Favorites"
    case settings = "Settings"

    var id: String { rawValue }

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .search:
            return "magnifyingglass"
        case .movies:
            return "film.fill"
        case .tvShows:
            return "tv.fill"
        case .favorites:
            return "heart.fill"
        case .settings:
            return "gear"
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(isVisible: .constant(true)) { item in
        print("Selected: \(item.title)")
    }
    .background(Color.black)
}
