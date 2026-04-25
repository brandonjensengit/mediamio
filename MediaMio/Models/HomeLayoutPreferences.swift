//
//  HomeLayoutPreferences.swift
//  MediaMio
//
//  Persistence model + pure ordering function for user-customized Home rows.
//

import Foundation

/// User overrides for the Home page row layout.
///
/// `rowOrder` is a positional override list keyed by `SectionType.stableKey`.
/// It does not need to contain every known section — keys not present fall to
/// the bottom of the visible list in raw server order. This means a brand-new
/// Jellyfin library appears at the bottom without the user having to touch
/// settings.
///
/// `hiddenRowKeys` is consulted before ordering: any section whose stableKey
/// is in this set is filtered out of the visible list entirely.
struct HomeLayoutPreferences: Codable, Equatable {
    var rowOrder: [String]
    var hiddenRowKeys: Set<String>

    static let `default` = HomeLayoutPreferences(rowOrder: [], hiddenRowKeys: [])
}

/// Apply the user's layout preferences to the raw section list returned by
/// `ContentService`. Pure function — no I/O, no UserDefaults, fully testable.
///
/// Ordering rules:
///   1. Hidden keys are filtered first.
///   2. Visible sections whose stableKey appears in `rowOrder` come first,
///      in the order saved.
///   3. Remaining visible sections (e.g. a brand-new library the user has
///      never seen) are appended at the bottom in their raw server order.
///
/// Stale keys in `rowOrder` (keys with no matching section — e.g. a deleted
/// library) are silently dropped from the output. They are intentionally NOT
/// pruned from the persisted preferences, so if the library reappears later
/// the user's saved position is honored.
func applyLayout(rawSections: [ContentSection],
                 preferences: HomeLayoutPreferences) -> [ContentSection] {
    let visible = rawSections.filter {
        !preferences.hiddenRowKeys.contains($0.type.stableKey)
    }
    var bySafeKey: [String: ContentSection] = [:]
    for section in visible {
        bySafeKey[section.type.stableKey] = section
    }

    var result: [ContentSection] = []
    var seen: Set<String> = []
    for key in preferences.rowOrder {
        if let section = bySafeKey[key] {
            result.append(section)
            seen.insert(key)
        }
    }
    for section in visible where !seen.contains(section.type.stableKey) {
        result.append(section)
    }
    return result
}
