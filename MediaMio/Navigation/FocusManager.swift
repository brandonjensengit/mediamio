//
//  FocusManager.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase A refactor: demoted from a parallel focus state machine to a thin
//  last-focus memo. SwiftUI's `@FocusState` is now the single source of truth
//  for "who is focused"; this class only remembers which item index was last
//  focused inside each row, so views can restore focus on re-entry.
//

import Combine
import Foundation
import SwiftUI

/// Last-focus memo for content rows.
///
/// The previous implementation was a full focus state machine (published current
/// section, history stack, hero-button enum, navigation helpers) running in
/// parallel with SwiftUI's own `@FocusState` and a UIKit `UIFocusGuide`
/// bridge. The three systems drifted out of sync and forced views into
/// brute-force `scrollTo` loops to compensate. This shrunken version keeps
/// only the data that SwiftUI doesn't already track for us: the last focused
/// item index per row, used purely for restoration.
@MainActor
final class FocusManager: ObservableObject {
    /// Required for `ObservableObject` so views can hold this as `@StateObject`,
    /// but intentionally never fired — focus mutations should not trigger view
    /// re-renders. SwiftUI's `@FocusState` already drives the visual focus
    /// ring; we only persist position data here for restoration.
    let objectWillChange = ObservableObjectPublisher()

    /// `SectionType.stableKey` → last focused itemIndex within that row.
    /// Keyed by stableKey rather than positional index so reorder/hide
    /// preserves restoration: "I was on Movies, position 4" survives the
    /// row moving from index 1 to 3.
    private var lastIndexByRow: [String: Int] = [:]

    /// Called by `ContentRow` whenever a poster card receives focus.
    func focusedOnRow(_ rowKey: String, itemIndex: Int) {
        lastIndexByRow[rowKey] = itemIndex
    }

    /// Returns the last focused item index for a row (or 0 if never focused).
    func lastFocusedItem(inRow rowKey: String) -> Int {
        lastIndexByRow[rowKey] ?? 0
    }

    /// Reset all stored positions (e.g. after a hard refresh).
    func reset() {
        lastIndexByRow.removeAll()
    }
}
