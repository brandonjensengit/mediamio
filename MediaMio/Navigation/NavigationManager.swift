//
//  NavigationManager.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 1: Core Navigation Structure
//

import Foundation
import SwiftUI
import Combine

@MainActor
class NavigationManager: ObservableObject {
    // MARK: - Published Properties

    // Tab selection
    @Published var selectedTab: Tab = .home

    // Detail view presentation
    @Published var presentedItem: MediaItem?

    // Player state
    @Published var showingPlayer: Bool = false
    @Published var currentPlayerItem: MediaItem?

    // Focus memory for content rows
    @Published var focusedRowIndex: Int = 0
    @Published var focusedItemIndices: [Int: Int] = [:] // Row index → Item index

    // Scroll position preservation
    @Published var homeScrollPosition: CGFloat = 0
    @Published var searchScrollPosition: CGFloat = 0
    @Published var libraryScrollPosition: CGFloat = 0

    // MARK: - Navigation Methods

    /// Present detail view for a media item
    func showDetail(for item: MediaItem) {
        presentedItem = item
        print("📱 Showing detail for: \(item.name)")
    }

    /// Start playing a media item
    func playItem(_ item: MediaItem) {
        currentPlayerItem = item

        // If detail sheet is open, dismiss it first before showing player
        if presentedItem != nil {
            presentedItem = nil
            // Delay showing player to allow sheet dismiss animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.showingPlayer = true
                print("▶️ Playing: \(item.name)")
            }
        } else {
            showingPlayer = true
            print("▶️ Playing: \(item.name)")
        }
    }

    /// Dismiss the detail view
    func dismissDetail() {
        presentedItem = nil
        print("📱 Dismissed detail view")
    }

    /// Close the video player
    func closePlayer() {
        showingPlayer = false
        currentPlayerItem = nil
        print("⏹️ Closed player")
    }

    // MARK: - Focus Memory

    /// Remember focus position for a specific row
    func rememberFocus(row: Int, itemIndex: Int) {
        focusedItemIndices[row] = itemIndex
        print("🎯 Remembered focus: Row \(row), Item \(itemIndex)")
    }

    /// Recall last focused item index for a row
    func recallFocus(for row: Int) -> Int {
        return focusedItemIndices[row] ?? 0
    }

    /// Clear all focus memory
    func clearFocusMemory() {
        focusedItemIndices.removeAll()
        focusedRowIndex = 0
    }

    // MARK: - Tab Navigation

    /// Switch to a specific tab
    func switchToTab(_ tab: Tab) {
        selectedTab = tab
        print("🔀 Switched to tab: \(tab.rawValue)")
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case home = "Home"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .search:
            return "magnifyingglass"
        case .library:
            return "square.stack.fill"
        case .settings:
            return "gearshape.fill"
        }
    }

    var title: String {
        return rawValue
    }
}
