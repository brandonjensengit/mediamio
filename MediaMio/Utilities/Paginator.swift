//
//  Paginator.swift
//  MediaMio
//
//  Shared pagination state machine for paged Jellyfin list endpoints.
//  Purpose: replace the duplicated `currentStartIndex` / `pageSize` /
//  `hasMoreContent` / `isLoading` / `isLoadingMore` bookkeeping that had
//  drifted between `LibraryViewModel` and `SearchViewModel`.
//  Constraint: never performs I/O itself. Callers pass a `loader` closure
//  that returns an `ItemsResponse`, and `Paginator` owns the index math,
//  the has-more decision, and the concurrent-load guards.
//

import Foundation

/// Canonical page shape returned by the loader closure. Matches Jellyfin's
/// `ItemsResponse` so the adapter can be a pass-through, but stays a local
/// protocol so tests don't need the full `MediaItem` decoder graph.
protocol PaginatedPage {
    associatedtype Item
    var items: [Item] { get }
    var totalRecordCount: Int? { get }
}

extension ItemsResponse: PaginatedPage {}

/// State machine that owns page-offset bookkeeping and the two
/// mutual-exclusion flags (`isLoading` for page-zero reloads,
/// `isLoadingMore` for tail-append). Callers observe `items` and the
/// flags directly; they call `reload()` on a fresh query and `loadMore()`
/// when the last visible cell appears.
///
/// Designed as a non-ObservableObject value-semantics-ish helper so the
/// owning ViewModel keeps control over `@Published`. The VM calls `apply`
/// and then mirrors the resulting state onto its own `@Published`
/// properties. That keeps SwiftUI wiring simple and side-steps nested
/// ObservableObject update issues.
@MainActor
final class Paginator<Item> {
    let pageSize: Int

    private(set) var items: [Item] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingMore: Bool = false
    private(set) var hasMore: Bool = true
    private(set) var totalRecordCount: Int?
    private(set) var currentStartIndex: Int = 0

    init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }

    /// True iff we can currently fire the first-page loader.
    var canReload: Bool { !isLoading }

    /// True iff we can currently fire a next-page loader.
    var canLoadMore: Bool { !isLoading && !isLoadingMore && hasMore }

    /// Reset pagination state for a fresh query. Does not clear `items`
    /// until the caller applies the first returned page — that way the
    /// UI doesn't flash empty during a refresh.
    func beginReload() {
        isLoading = true
        currentStartIndex = 0
        hasMore = true
        totalRecordCount = nil
    }

    func endReload() {
        isLoading = false
    }

    func beginLoadMore() {
        isLoadingMore = true
    }

    func endLoadMore() {
        isLoadingMore = false
    }

    /// Apply a page returned by the loader. Branch-on-`currentStartIndex`
    /// so the same method handles both "first page" (replace) and "next
    /// page" (append). Updates `hasMore` from the authoritative total if
    /// the server provided one; otherwise falls back to the page-full
    /// heuristic (a short final page ends pagination).
    func apply<Page: PaginatedPage>(_ page: Page) where Page.Item == Item {
        if currentStartIndex == 0 {
            items = page.items
        } else {
            items.append(contentsOf: page.items)
        }

        totalRecordCount = page.totalRecordCount
        currentStartIndex += page.items.count

        if let total = page.totalRecordCount {
            hasMore = currentStartIndex < total
        } else {
            hasMore = page.items.count >= pageSize
        }
    }

    /// Forget all state. Used when the owning VM wants to fully clear
    /// results (e.g. search cleared the query string).
    func reset() {
        items = []
        currentStartIndex = 0
        hasMore = true
        totalRecordCount = nil
        isLoading = false
        isLoadingMore = false
    }

    // MARK: - Status text helpers

    /// Human-readable status: "N of M items" when the server gave us a
    /// total, "N items" otherwise. Used by the Library status bar.
    func statusText(itemNoun: String = "items") -> String {
        if let total = totalRecordCount {
            return "\(items.count) of \(total) \(itemNoun)"
        } else if !items.isEmpty {
            return "\(items.count) \(itemNoun)"
        } else {
            return ""
        }
    }
}
