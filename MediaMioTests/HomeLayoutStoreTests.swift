//
//  HomeLayoutStoreTests.swift
//  MediaMioTests
//
//  Pure-logic tests for the Home row layout layer. The store is exercised
//  against an isolated UserDefaults suite so we don't pollute real settings.
//

import Testing
import Foundation
@testable import MediaMio

// MARK: - Fixtures

private func mkSection(_ type: ContentSection.SectionType, title: String? = nil) -> ContentSection {
    ContentSection(title: title ?? defaultTitle(type), items: [], type: type)
}

private func defaultTitle(_ type: ContentSection.SectionType) -> String {
    switch type {
    case .continueWatching: return "Continue Watching"
    case .recentlyAdded:    return "Recently Added"
    case .library(_, let name, _): return name
    case .recommended:      return "Recommended"
    case .favorites:        return "Favorites"
    }
}

private let cw  = mkSection(.continueWatching)
private let mov = mkSection(.library(id: "lib-1", name: "Movies", collectionType: "movies"))
private let tv  = mkSection(.library(id: "lib-2", name: "TV Shows", collectionType: "tvshows"))
private let mus = mkSection(.library(id: "lib-3", name: "Music", collectionType: "music"))

private let raw = [cw, mov, tv, mus]

// MARK: - applyLayout

@Suite("applyLayout — pure ordering function")
struct ApplyLayoutTests {

    @Test("empty preferences returns raw order untouched")
    func emptyPrefs() {
        let result = applyLayout(rawSections: raw, preferences: .default)
        #expect(result.map(\.type.stableKey) == raw.map(\.type.stableKey))
    }

    @Test("partial rowOrder puts known keys first, unknowns appended in raw order")
    func partialOrder() {
        let prefs = HomeLayoutPreferences(
            rowOrder: ["library.lib-2", "system.continueWatching"],
            hiddenRowKeys: []
        )
        let result = applyLayout(rawSections: raw, preferences: prefs)
        #expect(result.map(\.type.stableKey) == [
            "library.lib-2",          // TV Shows (saved first)
            "system.continueWatching", // CW (saved second)
            "library.lib-1",          // Movies (unknown to prefs → raw order)
            "library.lib-3"           // Music (unknown to prefs → raw order)
        ])
    }

    @Test("hiddenRowKeys filters before ordering")
    func hidden() {
        let prefs = HomeLayoutPreferences(
            rowOrder: [],
            hiddenRowKeys: ["library.lib-3", "system.continueWatching"]
        )
        let result = applyLayout(rawSections: raw, preferences: prefs)
        #expect(result.map(\.type.stableKey) == ["library.lib-1", "library.lib-2"])
    }

    @Test("stale rowOrder key (deleted library) silently dropped")
    func staleKey() {
        let prefs = HomeLayoutPreferences(
            rowOrder: ["library.deleted-99", "library.lib-1"],
            hiddenRowKeys: []
        )
        let result = applyLayout(rawSections: raw, preferences: prefs)
        // library.deleted-99 has no matching section, so it's dropped.
        // library.lib-1 (Movies) honors its saved first-place position.
        #expect(result.map(\.type.stableKey) == [
            "library.lib-1",
            "system.continueWatching",
            "library.lib-2",
            "library.lib-3"
        ])
    }

    @Test("new library on server appears at bottom")
    func newLibrary() {
        let prefs = HomeLayoutPreferences(
            rowOrder: ["library.lib-1", "library.lib-2"],
            hiddenRowKeys: []
        )
        // Music is a "new" library — not in saved order.
        let result = applyLayout(rawSections: raw, preferences: prefs)
        #expect(result.last?.type.stableKey == "library.lib-3")
    }

    @Test("hiddenRow with non-matching key is ignored without error")
    func hiddenStale() {
        let prefs = HomeLayoutPreferences(
            rowOrder: [],
            hiddenRowKeys: ["library.never-existed"]
        )
        let result = applyLayout(rawSections: raw, preferences: prefs)
        #expect(result.count == raw.count)
    }
}

// MARK: - Codable

@Suite("HomeLayoutPreferences Codable round-trip")
struct CodableTests {
    @Test("round-trip preserves order and hidden set")
    func roundTrip() throws {
        let prefs = HomeLayoutPreferences(
            rowOrder: ["library.lib-2", "system.continueWatching", "library.lib-1"],
            hiddenRowKeys: ["library.lib-3", "system.recentlyAdded"]
        )
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(HomeLayoutPreferences.self, from: data)
        #expect(decoded == prefs)
        #expect(decoded.rowOrder == prefs.rowOrder)
        #expect(decoded.hiddenRowKeys == prefs.hiddenRowKeys)
    }
}

// MARK: - Store mutations

@MainActor
@Suite("HomeLayoutStore — mutations")
struct StoreTests {

    private func makeStore() -> HomeLayoutStore {
        // Isolated UserDefaults so tests don't bleed.
        let suiteName = "HomeLayoutStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = HomeLayoutStore(defaults: defaults)
        store.updateKnownSections(raw)
        return store
    }

    @Test("moveUp on first row is a no-op")
    func moveUpFirst() {
        let store = makeStore()
        let firstKey = raw[0].type.stableKey
        store.moveUp(key: firstKey)
        // Either rowOrder stays empty, or — if materialized — first key still leads.
        if !store.preferences.rowOrder.isEmpty {
            #expect(store.preferences.rowOrder.first == firstKey)
        }
    }

    @Test("moveDown on last row is a no-op")
    func moveDownLast() {
        let store = makeStore()
        let lastKey = raw.last!.type.stableKey
        store.moveDown(key: lastKey)
        if !store.preferences.rowOrder.isEmpty {
            #expect(store.preferences.rowOrder.last == lastKey)
        }
    }

    @Test("moveUp swaps with previous row")
    func moveUpSwaps() {
        let store = makeStore()
        // Move TV Shows (index 2 in raw) up — should swap with Movies (index 1).
        store.moveUp(key: "library.lib-2")
        let order = store.preferences.rowOrder
        #expect(order.firstIndex(of: "library.lib-2")! < order.firstIndex(of: "library.lib-1")!)
    }

    @Test("hide adds to hiddenRowKeys")
    func hide() {
        let store = makeStore()
        store.hide(key: "library.lib-3")
        #expect(store.preferences.hiddenRowKeys.contains("library.lib-3"))
    }

    @Test("show removes from hiddenRowKeys and appends to rowOrder")
    func show() {
        let store = makeStore()
        store.hide(key: "library.lib-3")
        store.show(key: "library.lib-3")
        #expect(!store.preferences.hiddenRowKeys.contains("library.lib-3"))
        #expect(store.preferences.rowOrder.contains("library.lib-3"))
    }

    @Test("reset wipes both order and hidden set")
    func reset() {
        let store = makeStore()
        store.hide(key: "library.lib-3")
        store.moveUp(key: "library.lib-2")
        store.reset()
        #expect(store.preferences.rowOrder.isEmpty)
        #expect(store.preferences.hiddenRowKeys.isEmpty)
    }

    @Test("preferences persist across store instances")
    func persistence() {
        let suiteName = "HomeLayoutStoreTests-Persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storeA = HomeLayoutStore(defaults: defaults)
        storeA.updateKnownSections(raw)
        storeA.hide(key: "library.lib-3")

        let storeB = HomeLayoutStore(defaults: defaults)
        #expect(storeB.preferences.hiddenRowKeys.contains("library.lib-3"))
    }

    @Test("regression: moveUp works after a partial rowOrder from show()")
    func moveUpAfterPartialRowOrder() {
        // Repro of the production bug: a previous bad version of show()
        // could leave rowOrder partially populated (e.g. just ["library.lib-3"]).
        // Subsequent moveUp on DVR (not in rowOrder) silently no-op'd because
        // firstIndex(of:) returned nil and the old code didn't sync.
        let store = makeStore()
        store.hide(key: "library.lib-3")
        store.show(key: "library.lib-3")
        // rowOrder now contains all visible keys, sanitized by syncOrder.
        // Move TV Shows up — should swap with Movies regardless of prior state.
        store.moveUp(key: "library.lib-2")
        let order = store.preferences.rowOrder
        let movieIdx = order.firstIndex(of: "library.lib-1")!
        let tvIdx = order.firstIndex(of: "library.lib-2")!
        #expect(tvIdx < movieIdx, "Move Up should swap TV above Movies; got order: \(order)")
    }

    @Test("rowOrder is always a complete list of visible keys after any mutation")
    func rowOrderInvariant() {
        let store = makeStore()
        store.hide(key: "library.lib-3")           // hide one
        store.moveUp(key: "library.lib-2")         // mutate another
        let visibleKeys = Set(raw.map(\.type.stableKey))
            .subtracting(["library.lib-3"])
        #expect(Set(store.preferences.rowOrder) == visibleKeys,
                "rowOrder should equal the set of visible keys; got \(store.preferences.rowOrder)")
    }

    @Test("visibleCount and hiddenCount reflect current state")
    func counts() {
        let store = makeStore()
        #expect(store.visibleCount == raw.count)
        #expect(store.hiddenCount == 0)
        store.hide(key: "library.lib-3")
        #expect(store.visibleCount == raw.count - 1)
        #expect(store.hiddenCount == 1)
    }
}
