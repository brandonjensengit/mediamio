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

    // Player state. Two separate flags so the correct presenter fires
    // without making the other presenter race on the same boolean — tvOS
    // only has one modal context per view, so binding both a root-level
    // cover and a sheet-level cover to the same flag results in one of
    // them silently losing the race. `playItem` picks which flag to set
    // based on whether a Detail sheet is currently open.
    @Published var showingPlayerAtRoot: Bool = false     // from Hero / Continue Watching / Library row
    @Published var showingPlayerOverDetail: Bool = false // from inside an open Detail sheet
    @Published var currentPlayerItem: MediaItem?
    // Start offset override, set when launching playback from a chapter tap
    // on Detail. Nil = "use the item's resume data, if any".
    @Published var currentPlayerStartTicks: Int64?

    // Focus memory for content rows. Keyed by `SectionType.stableKey` so
    // reorder/hide doesn't invalidate restoration positions.
    @Published var focusedRowKey: String? = nil
    @Published var focusedItemIndices: [String: Int] = [:] // Row stableKey → Item index

    /// Number of pushed views currently on screen across all NavigationStacks.
    /// Each pushed view should bump this on `.onAppear` and decrement on
    /// `.onDisappear`. Used by the top-level Menu handler to detect "there's
    /// nested nav that should pop first, don't switch tabs yet."
    ///
    /// We use a counter instead of the `NavigationPath`-based API because
    /// existing settings NavigationLinks use the `destination:` syntax,
    /// which doesn't publish into a bound path. Refactoring all of them is
    /// out of scope; a counter is surgical.
    @Published var pushedViewCount: Int = 0

    func registerPushedView()   { pushedViewCount += 1 }
    func unregisterPushedView() { pushedViewCount = max(0, pushedViewCount - 1) }

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

    /// Start playing a media item. Pass `startPositionTicks` to jump to a
    /// specific offset (chapter tap); omit it to use the item's resume data.
    ///
    /// If the Detail sheet is open, the player presents from the sheet's
    /// own modal context (`showingPlayerOverDetail`) — the sheet stays
    /// mounted underneath, so Menu-back returns to Detail, not Home, and
    /// there is no sheet-dismiss / re-present flicker.
    func playItem(_ item: MediaItem, startPositionTicks: Int64? = nil) {
        currentPlayerItem = item
        currentPlayerStartTicks = startPositionTicks

        if presentedItem != nil {
            showingPlayerOverDetail = true
        } else {
            showingPlayerAtRoot = true
        }
        print("▶️ Playing: \(item.name)")
    }

    /// Invoked by whichever `.fullScreenCover` presented the player, on
    /// dismiss. Clears the transient player state; the underlying presenter
    /// (root view or Detail sheet) returns on its own.
    func handlePlayerDismissed() {
        currentPlayerItem = nil
        currentPlayerStartTicks = nil
    }

    /// Dismiss the detail view
    func dismissDetail() {
        presentedItem = nil
        print("📱 Dismissed detail view")
    }

    /// Close the video player. Currently unused — the fullScreenCover
    /// binding drives dismissal; kept for callers that may want to force-
    /// close the player programmatically later.
    func closePlayer() {
        showingPlayerAtRoot = false
        showingPlayerOverDetail = false
        currentPlayerItem = nil
        currentPlayerStartTicks = nil
        print("⏹️ Closed player")
    }

    // MARK: - Focus Memory

    /// Remember focus position for a specific row, keyed by stableKey.
    func rememberFocus(rowKey: String, itemIndex: Int) {
        focusedItemIndices[rowKey] = itemIndex
        print("🎯 Remembered focus: Row \(rowKey), Item \(itemIndex)")
    }

    /// Recall last focused item index for a row.
    func recallFocus(forRowKey rowKey: String) -> Int {
        return focusedItemIndices[rowKey] ?? 0
    }

    /// Clear all focus memory
    func clearFocusMemory() {
        focusedItemIndices.removeAll()
        focusedRowKey = nil
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
