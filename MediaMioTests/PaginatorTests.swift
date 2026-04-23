//
//  PaginatorTests.swift
//  MediaMioTests
//
//  Locks the shared pagination state machine used by LibraryViewModel +
//  SearchViewModel. Pre-extraction, both VMs had near-identical offset /
//  has-more / loading bookkeeping, and they had already drifted (Library
//  used `totalItemCount`, Search used the same name for an independent
//  field; the `hasMoreContent` fallback heuristic diverged in two places).
//  These tests pin the contract so regressions surface in CI instead of
//  at runtime when the Library quietly stops paginating past page 2.
//

import Testing
@testable import MediaMio

private struct FakePage: PaginatedPage {
    let items: [Int]
    let totalRecordCount: Int?
}

@MainActor
struct PaginatorTests {

    @Test("Fresh paginator can reload and load-more")
    func initialFlags() {
        let p = Paginator<Int>()
        #expect(p.canReload == true)
        #expect(p.canLoadMore == true)
        #expect(p.hasMore == true)
        #expect(p.items.isEmpty)
        #expect(p.currentStartIndex == 0)
    }

    @Test("beginReload locks out a second reload")
    func reloadGuardsReentry() {
        let p = Paginator<Int>()
        p.beginReload()
        #expect(p.canReload == false)
        #expect(p.isLoading == true)
        p.endReload()
        #expect(p.canReload == true)
        #expect(p.isLoading == false)
    }

    @Test("canLoadMore is false while a full reload is in flight")
    func reloadSuppressesLoadMore() {
        let p = Paginator<Int>()
        p.beginReload()
        #expect(p.canLoadMore == false)
    }

    @Test("beginLoadMore locks out a second loadMore")
    func loadMoreGuardsReentry() {
        let p = Paginator<Int>()
        p.beginLoadMore()
        #expect(p.canLoadMore == false)
        p.endLoadMore()
        #expect(p.canLoadMore == true)
    }

    @Test("First page replaces items and advances the offset")
    func firstPageReplaces() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 10))
        #expect(p.items == [1, 2, 3])
        #expect(p.currentStartIndex == 3)
        #expect(p.hasMore == true)
        #expect(p.totalRecordCount == 10)
    }

    @Test("Subsequent page appends and advances the offset")
    func nextPageAppends() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 6))
        p.apply(FakePage(items: [4, 5, 6], totalRecordCount: 6))
        #expect(p.items == [1, 2, 3, 4, 5, 6])
        #expect(p.currentStartIndex == 6)
        #expect(p.hasMore == false)  // we've caught up to the total
    }

    @Test("Total record count is authoritative for hasMore")
    func totalBeatsHeuristic() {
        let p = Paginator<Int>(pageSize: 3)
        // Page is full (3/3) but server says only 3 items exist — hasMore
        // must be false. The page-full heuristic would otherwise say true
        // and we'd fire a wasted second fetch.
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 3))
        #expect(p.hasMore == false)
    }

    @Test("Without a total, a short page ends pagination")
    func shortPageEndsPagination() {
        let p = Paginator<Int>(pageSize: 5)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: nil))
        #expect(p.hasMore == false)
    }

    @Test("Without a total, a full page keeps pagination open")
    func fullPageWithoutTotalContinues() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: nil))
        #expect(p.hasMore == true)
    }

    @Test("Reloading mid-pagination restores page-zero semantics")
    func reloadResetsOffset() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 6))
        p.apply(FakePage(items: [4, 5, 6], totalRecordCount: 6))
        #expect(p.currentStartIndex == 6)

        p.beginReload()
        // During reload, offset has been reset so the next apply() replaces
        #expect(p.currentStartIndex == 0)
        #expect(p.hasMore == true)
        p.apply(FakePage(items: [10, 20], totalRecordCount: 2))
        p.endReload()

        #expect(p.items == [10, 20])   // not appended
        #expect(p.hasMore == false)
    }

    @Test("reset() wipes everything back to empty-and-ready")
    func resetWipesState() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 6))
        p.beginLoadMore()

        p.reset()

        #expect(p.items.isEmpty)
        #expect(p.currentStartIndex == 0)
        #expect(p.hasMore == true)
        #expect(p.totalRecordCount == nil)
        #expect(p.isLoading == false)
        #expect(p.isLoadingMore == false)
    }

    @Test("statusText prints 'N of M' when server gave a total")
    func statusTextWithTotal() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2, 3], totalRecordCount: 10))
        #expect(p.statusText() == "3 of 10 items")
        #expect(p.statusText(itemNoun: "results") == "3 of 10 results")
    }

    @Test("statusText prints 'N results' when no total is known")
    func statusTextWithoutTotal() {
        let p = Paginator<Int>(pageSize: 3)
        p.apply(FakePage(items: [1, 2], totalRecordCount: nil))
        #expect(p.statusText(itemNoun: "results") == "2 results")
    }

    @Test("statusText is empty when we haven't loaded anything yet")
    func statusTextEmptyInitially() {
        let p = Paginator<Int>()
        #expect(p.statusText() == "")
    }

    @Test("Empty page from the server ends pagination cleanly")
    func emptyPageEndsPagination() {
        let p = Paginator<Int>(pageSize: 5)
        p.apply(FakePage(items: [], totalRecordCount: 0))
        #expect(p.items.isEmpty)
        #expect(p.hasMore == false)
        #expect(p.currentStartIndex == 0)
    }
}
