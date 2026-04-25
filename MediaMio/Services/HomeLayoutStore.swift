//
//  HomeLayoutStore.swift
//  MediaMio
//
//  Singleton owning the user's Home row customization (order + hidden set).
//  Mutation API is consumed by both the inline row context menu and the
//  Home Layout settings screen.
//

import Foundation
import Combine

/// Lightweight metadata describing a section the user could place on Home.
/// Kept separate from `ContentSection` because the Settings screen needs to
/// list rows that aren't currently in `HomeViewModel.sections` — e.g.
/// Continue Watching when there's nothing to resume, or a library the user
/// has hidden.
struct HomeRowDescriptor: Identifiable, Hashable {
    let key: String
    let title: String
    var id: String { key }
}

@MainActor
final class HomeLayoutStore: ObservableObject {
    static let shared = HomeLayoutStore()

    private static let preferencesKey = "home.layoutPreferences"

    @Published private(set) var preferences: HomeLayoutPreferences

    /// Every row the VM has seen on a successful load, in their raw server
    /// order. Refreshed by `HomeViewModel` on each `loadContent`. The
    /// Settings screen reads this so it can show hidden rows that aren't in
    /// `HomeViewModel.sections`, and so empty-but-known rows (e.g. Continue
    /// Watching with no items today) still appear as configurable.
    @Published private(set) var knownRows: [HomeRowDescriptor] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferences = Self.loadPreferences(from: defaults)
    }

    // MARK: - Mutations

    /// Every mutation calls `syncOrder()` first so `preferences.rowOrder` is
    /// guaranteed to be a complete, ordered list of currently-visible keys.
    /// Without this, partially-populated `rowOrder` (e.g. just one key from
    /// a previous `show()`) caused `firstIndex(of:)` lookups to silently
    /// fail and the mutation to no-op.

    func moveUp(key: String) {
        syncOrder()
        guard let idx = preferences.rowOrder.firstIndex(of: key), idx > 0 else { return }
        preferences.rowOrder.swapAt(idx, idx - 1)
        save()
    }

    func moveDown(key: String) {
        syncOrder()
        guard let idx = preferences.rowOrder.firstIndex(of: key),
              idx < preferences.rowOrder.count - 1 else { return }
        preferences.rowOrder.swapAt(idx, idx + 1)
        save()
    }

    func hide(key: String) {
        preferences.hiddenRowKeys.insert(key)
        // Drop from rowOrder so a future `show()` lands the row at the
        // bottom of the visible list (matches the UX spec).
        preferences.rowOrder.removeAll { $0 == key }
        save()
    }

    func show(key: String) {
        preferences.hiddenRowKeys.remove(key)
        syncOrder() // appends restored key at the end of rowOrder
        save()
    }

    func reset() {
        preferences = HomeLayoutPreferences.default
        save()
    }

    /// Ensure `preferences.rowOrder` contains exactly the currently-visible
    /// keys. Existing keys keep their saved order; new visible keys (e.g.
    /// just-restored or new server libraries) are appended in `knownRows`
    /// order. Keys for sections that no longer exist are dropped.
    private func syncOrder() {
        let visibleKeys = knownRows
            .map(\.key)
            .filter { !preferences.hiddenRowKeys.contains($0) }
        let visibleSet = Set(visibleKeys)
        var newOrder = preferences.rowOrder.filter { visibleSet.contains($0) }
        let inOrder = Set(newOrder)
        for key in visibleKeys where !inOrder.contains(key) {
            newOrder.append(key)
        }
        if newOrder != preferences.rowOrder {
            preferences.rowOrder = newOrder
        }
    }

    // MARK: - Known sections

    /// Called by `HomeViewModel` after each successful `loadContent`. Stores
    /// the raw (pre-layout) section list so the Settings screen can show
    /// every possible row, including hidden ones.
    func updateKnownSections(_ rawSections: [ContentSection]) {
        let descriptors = rawSections.map {
            HomeRowDescriptor(key: $0.type.stableKey, title: $0.title)
        }
        // Merge: keep existing descriptors that aren't in this load (e.g. a
        // hidden row that didn't come back from the server because it was
        // empty), but update titles for any that are present.
        var keyed: [String: HomeRowDescriptor] = [:]
        for existing in knownRows { keyed[existing.key] = existing }
        for new in descriptors { keyed[new.key] = new }
        // Order: latest-seen rows first (in load order), then any prior-only.
        var ordered: [HomeRowDescriptor] = []
        var seen: Set<String> = []
        for d in descriptors {
            ordered.append(d)
            seen.insert(d.key)
        }
        for prior in knownRows where !seen.contains(prior.key) {
            ordered.append(prior)
        }
        knownRows = ordered
    }

    // MARK: - Counts (for Settings subtitle)

    var visibleCount: Int {
        knownRows.filter { !preferences.hiddenRowKeys.contains($0.key) }.count
    }

    var hiddenCount: Int {
        knownRows.filter { preferences.hiddenRowKeys.contains($0.key) }.count
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(preferences)
            defaults.set(data, forKey: Self.preferencesKey)
        } catch {
            DebugLog.verbose("❌ HomeLayoutStore save failed: \(error)")
        }
    }

    private static func loadPreferences(from defaults: UserDefaults) -> HomeLayoutPreferences {
        guard let data = defaults.data(forKey: preferencesKey) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(HomeLayoutPreferences.self, from: data)
        } catch {
            DebugLog.verbose("❌ HomeLayoutStore load failed: \(error)")
            return .default
        }
    }

}
