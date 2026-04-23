//
//  LibraryViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var sortOption: SortOption = .alphabetical
    @Published var filters = LibraryFilters()
    @Published var availableGenres: [Genre] = []
    @Published var availableYears: [Int] = []

    /// Active letter filter, set by tapping a letter in the A-Z rail. Nil =
    /// show everything. Only takes effect while sort is alphabetical.
    @Published var activeLetter: String?

    private let section: ContentSection
    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    private let paginator = Paginator<MediaItem>(pageSize: 50)
    private var filterPersistenceKey: String {
        "filters_\(libraryId ?? "unknown")"
    }

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    var title: String {
        section.title
    }

    var libraryId: String? {
        if case .library(let id, _) = section.type {
            return id
        }
        return nil
    }

    var itemTypes: [String]? {
        if case .library(_, let name) = section.type {
            // Determine item types based on library name/type
            if name.lowercased().contains("movie") {
                return ["Movie"]
            } else if name.lowercased().contains("tv") || name.lowercased().contains("show") {
                return ["Series"]
            }
        }
        return nil
    }

    init(
        section: ContentSection,
        contentService: ContentService,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator? = nil
    ) {
        self.section = section
        self.contentService = contentService
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator

        // Load saved filters for this library
        if let libraryId = libraryId,
           let savedFilters = FilterPersistence.load(for: libraryId) {
            self.filters = savedFilters
            print("📂 Restored \(savedFilters.activeCount) saved filters for library: \(libraryId)")
        }
    }

    // MARK: - Sort Options

    enum SortOption: String, CaseIterable, Identifiable {
        case alphabetical = "Name"
        case dateAdded = "DateCreated"
        case releaseDate = "PremiereDate"
        case rating = "CommunityRating"
        case runtime = "Runtime"
        case criticRating = "CriticRating"
        case playCount = "PlayCount"
        case random = "Random"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .alphabetical: return "A-Z"
            case .dateAdded: return "Date Added"
            case .releaseDate: return "Release Date"
            case .rating: return "Rating"
            case .runtime: return "Runtime"
            case .criticRating: return "Critic Rating"
            case .playCount: return "Play Count"
            case .random: return "Random"
            }
        }

        var sortBy: String {
            rawValue
        }

        var sortOrder: String {
            switch self {
            case .alphabetical, .releaseDate:
                return "Ascending"
            case .dateAdded, .rating, .runtime, .criticRating, .playCount:
                return "Descending"
            case .random:
                return "Ascending"
            }
        }
    }

    // MARK: - Filter Methods

    /// Apply current filters and reload content
    func applyFilters() async {
        print("🔍 Applying filters: \(filters.activeCount) active")

        // Save filters
        if let libraryId = libraryId {
            FilterPersistence.save(filters, for: libraryId)
        }

        await loadContent()
    }

    /// Clear all filters and reload
    func clearFilters() async {
        print("🧹 Clearing all filters")
        filters.clear()

        // Clear saved filters
        if let libraryId = libraryId {
            FilterPersistence.clear(for: libraryId)
        }

        await loadContent()
    }

    /// Load available filter options (genres, years)
    func loadFilterOptions() async {
        guard let libraryId = libraryId else { return }

        print("📋 Loading filter options for library: \(libraryId)")

        // Load genres from items (once we have items)
        let uniqueGenres = Set(items.flatMap { $0.genres ?? [] })
        let matchedGenres = Genre.allCases.filter { genre in
            uniqueGenres.contains(genre.rawValue)
        }
        availableGenres = matchedGenres.sorted { $0.rawValue < $1.rawValue }

        // Load years from items
        let years = items.compactMap { $0.productionYear }
        availableYears = Array(Set(years)).sorted(by: >)

        print("✅ Loaded \(availableGenres.count) genres, \(availableYears.count) years")
    }

    // MARK: - Load Content

    func loadContent() async {
        guard paginator.canReload else { return }

        print("📚 Loading library content: \(title)")
        errorMessage = nil
        paginator.beginReload()
        isLoading = true

        await loadItems()

        paginator.endReload()
        isLoading = false
    }

    func loadMore() async {
        guard paginator.canLoadMore else { return }

        print("📚 Loading more items (startIndex: \(paginator.currentStartIndex))")
        paginator.beginLoadMore()
        isLoadingMore = true

        await loadItems()

        paginator.endLoadMore()
        isLoadingMore = false
    }

    private func loadItems() async {
        guard let libraryId = libraryId else {
            errorMessage = "Invalid library"
            return
        }

        do {
            let response = try await contentService.loadLibraryContent(
                libraryId: libraryId,
                itemTypes: itemTypes,
                filters: filters.isActive ? filters : nil,
                nameStartsWith: letterFilterForCurrentRequest,
                limit: paginator.pageSize,
                startIndex: paginator.currentStartIndex,
                sortBy: sortOption.sortBy,
                sortOrder: sortOption.sortOrder
            )

            paginator.apply(response)
            items = paginator.items

            print("✅ Loaded \(response.items.count) items (total: \(items.count), hasMore: \(paginator.hasMore))")

        } catch {
            print("❌ Failed to load library content: \(error)")
            errorMessage = "Failed to load content: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        await loadContent()
    }

    func changeSortOption(_ option: SortOption) async {
        guard option != sortOption else { return }

        print("🔄 Changing sort to: \(option.displayName)")
        sortOption = option
        // Letter-jump is only meaningful under alphabetical sort — clear it
        // when the user switches to a different ordering.
        if option != .alphabetical {
            activeLetter = nil
        }
        await loadContent()
    }

    // MARK: - Letter Jump

    /// Returns the prefix to send with the current request, or nil if letter
    /// filtering should not apply (non-alphabetical sort).
    private var letterFilterForCurrentRequest: String? {
        guard sortOption == .alphabetical else { return nil }
        return activeLetter
    }

    /// Show only items starting with the given single letter (or nil to clear).
    /// Special case: pass "#" to request items that start with a non-letter
    /// (digit or symbol) — Jellyfin's `NameStartsWith=#` matches digits.
    func jumpToLetter(_ letter: String?) async {
        guard letter != activeLetter else { return }
        print("🔤 Letter jump → \(letter ?? "all")")
        activeLetter = letter
        await loadContent()
    }

    // MARK: - Search

    func searchLibrary(query: String, limit: Int = 100) async throws -> [MediaItem] {
        guard !query.isEmpty else { return [] }

        print("🔍 Searching library '\(title)' for: '\(query)'")

        let response = try await contentService.searchItems(
            searchTerm: query,
            includeItemTypes: itemTypes,
            limit: limit,
            startIndex: 0
        )

        print("✅ Found \(response.items.count) results")
        return response.items
    }

    // MARK: - Actions

    func selectItem(_ item: MediaItem) {
        print("📺 Selected: \(item.name)")
        navigationCoordinator?.navigate(to: item)
    }

    // MARK: - Computed Properties

    var hasContent: Bool {
        !items.isEmpty
    }

    var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    var statusText: String {
        if let total = paginator.totalRecordCount {
            return "\(items.count) of \(total) items"
        } else {
            return "\(items.count) items"
        }
    }
}
