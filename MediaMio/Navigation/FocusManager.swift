//
//  FocusManager.swift
//  MediaMio
//
//  Created by Claude Code
//  Netflix-style Focus Management for tvOS
//

import Foundation
import SwiftUI
import Combine

/// Manages focus state and navigation across the home screen
/// Provides Netflix-style focus restoration and smooth navigation between sections
@MainActor
class FocusManager: ObservableObject {
    // MARK: - Focus Section Tracking

    /// Current focused section
    @Published var focusedSection: FocusSection = .hero

    /// Last focused section (for restoration)
    @Published var previousSection: FocusSection?

    /// Which row currently has focus (0-indexed)
    @Published var focusedRowIndex: Int = 0

    /// Item index within each row (rowIndex -> itemIndex)
    @Published var focusedItemInRow: [Int: Int] = [:]

    /// Which hero button has focus (playButton vs infoButton)
    @Published var focusedHeroButton: HeroButton = .play

    // MARK: - Focus History Stack

    /// Stack of previous focus positions for back navigation
    private var focusHistory: [FocusPosition] = []

    // MARK: - Focus Sections

    enum FocusSection: Hashable {
        case hero
        case row(index: Int)
    }

    enum HeroButton {
        case play
        case info
    }

    struct FocusPosition {
        let section: FocusSection
        let itemIndex: Int?
        let heroButton: HeroButton?
    }

    // MARK: - Focus Tracking

    /// Called when focus moves to hero section
    func focusedOnHero(button: HeroButton = .play) {
        print("🎯 Focus: Hero section (\(button == .play ? "Play" : "Info") button)")
        previousSection = focusedSection
        focusedSection = .hero
        focusedHeroButton = button
    }

    /// Called when focus moves to a content row
    func focusedOnRow(_ rowIndex: Int, itemIndex: Int) {
        print("🎯 Focus: Row \(rowIndex), Item \(itemIndex)")
        previousSection = focusedSection
        focusedSection = .row(index: rowIndex)
        focusedRowIndex = rowIndex
        focusedItemInRow[rowIndex] = itemIndex
    }

    /// Remember current focus position for later restoration
    func pushFocusPosition() {
        let position = FocusPosition(
            section: focusedSection,
            itemIndex: focusedItemInRow[focusedRowIndex],
            heroButton: focusedSection == .hero ? focusedHeroButton : nil
        )
        focusHistory.append(position)
        print("📚 Pushed focus position: \(focusedSection), history depth: \(focusHistory.count)")
    }

    /// Restore previous focus position
    func popFocusPosition() -> FocusPosition? {
        guard let position = focusHistory.popLast() else {
            print("📚 No focus position to restore")
            return nil
        }
        print("📚 Popped focus position: \(position.section), history depth: \(focusHistory.count)")
        return position
    }

    /// Clear focus history
    func clearHistory() {
        focusHistory.removeAll()
        print("📚 Cleared focus history")
    }

    // MARK: - Focus Restoration Helpers

    /// Get the last focused item index for a row
    func lastFocusedItem(inRow rowIndex: Int) -> Int {
        return focusedItemInRow[rowIndex] ?? 0
    }

    /// Should focus return to hero when navigating up from first row?
    func shouldReturnToHero(fromRow rowIndex: Int) -> Bool {
        return rowIndex == 0
    }

    /// Get which hero button should receive focus
    func heroButtonToFocus() -> HeroButton {
        return focusedHeroButton
    }

    // MARK: - Navigation Helpers

    /// Check if we can navigate up from current position
    func canNavigateUp() -> Bool {
        switch focusedSection {
        case .hero:
            return false  // Can't go above hero
        case .row(let index):
            return index >= 0  // Can always go up from rows (either to previous row or hero)
        }
    }

    /// Check if we can navigate down from current position
    func canNavigateDown(totalRows: Int) -> Bool {
        switch focusedSection {
        case .hero:
            return totalRows > 0  // Can go down if there are rows
        case .row(let index):
            return index < totalRows - 1  // Can go down if not on last row
        }
    }

    /// Get the target section when navigating up
    func targetSectionWhenNavigatingUp() -> FocusSection? {
        switch focusedSection {
        case .hero:
            return nil  // Can't go up from hero
        case .row(let index):
            if index == 0 {
                return .hero  // First row → hero
            } else {
                return .row(index: index - 1)  // Go to previous row
            }
        }
    }

    /// Get the target section when navigating down
    func targetSectionWhenNavigatingDown(totalRows: Int) -> FocusSection? {
        switch focusedSection {
        case .hero:
            return totalRows > 0 ? .row(index: 0) : nil  // Hero → first row
        case .row(let index):
            return index < totalRows - 1 ? .row(index: index + 1) : nil  // Go to next row
        }
    }

    // MARK: - Debug

    func printState() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎯 FOCUS STATE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   Current section: \(focusedSection)")
        print("   Previous section: \(previousSection ?? .hero)")
        print("   Focused row: \(focusedRowIndex)")
        print("   Focused items: \(focusedItemInRow)")
        print("   Hero button: \(focusedHeroButton == .play ? "Play" : "Info")")
        print("   History depth: \(focusHistory.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}
