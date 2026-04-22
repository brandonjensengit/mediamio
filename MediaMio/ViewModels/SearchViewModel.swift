//
//  SearchViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var results: [MediaItem] = []
    @Published var isSearching: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var filterType: FilterType = .all
    @Published var recentSearches: [String] = []

    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var currentStartIndex: Int = 0
    private let pageSize: Int = 50
    private var hasMoreContent: Bool = true
    private var totalItemCount: Int?

    // Hard cap so the recents list doesn't grow unbounded in UserDefaults.
    // 10 is the sweet spot seen in Netflix / Apple TV / YouTube recents.
    private let maxRecentSearches: Int = 10

    // A search is only worth recording once the user has committed to it —
    // i.e. it returned results and they chose something OR typed for a few
    // seconds. We commit on successful search completion to avoid recording
    // every keystroke of the debounce buffer.

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    init(
        contentService: ContentService,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator? = nil
    ) {
        self.contentService = contentService
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator

        loadRecentSearches()
        setupSearchDebouncing()
    }

    // MARK: - Filter Types

    enum FilterType: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"

        var id: String { rawValue }

        var itemTypes: [String]? {
            switch self {
            case .all:
                return nil
            case .movies:
                return ["Movie"]
            case .tvShows:
                return ["Series"]
            }
        }
    }

    // MARK: - Search Debouncing

    private func setupSearchDebouncing() {
        // Debounce search queries (wait 500ms after user stops typing)
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        // Cancel any ongoing search
        searchTask?.cancel()

        // Clear results if query is empty
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        print("🔍 Searching for: '\(query)' (filter: \(filterType.rawValue))")
        isSearching = true
        errorMessage = nil
        currentStartIndex = 0
        hasMoreContent = true

        searchTask = Task {
            await loadSearchResults()
        }

        await searchTask?.value
        isSearching = false
    }

    private func loadSearchResults() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        do {
            let response = try await contentService.searchItems(
                searchTerm: query,
                includeItemTypes: filterType.itemTypes,
                limit: pageSize,
                startIndex: currentStartIndex
            )

            if Task.isCancelled { return }

            if currentStartIndex == 0 {
                // First load - replace all results
                results = response.items
            } else {
                // Pagination - append results
                results.append(contentsOf: response.items)
            }

            // Update pagination state
            totalItemCount = response.totalRecordCount
            currentStartIndex += response.items.count

            // Check if there's more content
            if let total = totalItemCount {
                hasMoreContent = currentStartIndex < total
            } else {
                hasMoreContent = response.items.count >= pageSize
            }

            print("✅ Found \(response.items.count) results (total: \(results.count), hasMore: \(hasMoreContent))")

            // Record the query once we know it matched something. Queries
            // that return zero results aren't worth re-offering.
            if currentStartIndex == response.items.count, !response.items.isEmpty {
                commitRecent(query: query)
            }

        } catch {
            if Task.isCancelled { return }

            print("❌ Search failed: \(error)")
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    func loadMore() async {
        guard !isLoadingMore, !isSearching, hasMoreContent else { return }
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        print("🔍 Loading more results (startIndex: \(currentStartIndex))")
        isLoadingMore = true

        await loadSearchResults()

        isLoadingMore = false
    }

    func changeFilter(_ filter: FilterType) {
        guard filter != filterType else { return }

        print("🔄 Changing filter to: \(filter.rawValue)")
        filterType = filter

        // Re-trigger search with new filter
        Task {
            await performSearch(query: searchQuery)
        }
    }

    func clearSearch() {
        searchQuery = ""
        results = []
        errorMessage = nil
    }

    // MARK: - Actions

    func selectItem(_ item: MediaItem) {
        print("📺 Selected search result: \(item.name)")
        navigationCoordinator?.navigate(to: item)
    }

    // MARK: - Recent Searches

    /// Run a previously-recorded search by filling the text field, which
    /// re-triggers the debounced search pipeline.
    func runRecentSearch(_ query: String) {
        searchQuery = query
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        persistRecentSearches()
    }

    func clearAllRecentSearches() {
        recentSearches = []
        persistRecentSearches()
    }

    private func commitRecent(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }  // Single-char searches aren't useful recents.

        // Move-to-front LRU: remove any case-insensitive duplicate, then
        // prepend. Keeping originals lets us preserve the user's capitalization.
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        persistRecentSearches()
    }

    private func loadRecentSearches() {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.recentSearches),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        recentSearches = decoded
    }

    private func persistRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKeys.recentSearches)
        }
    }

    // MARK: - Computed Properties

    var hasResults: Bool {
        !results.isEmpty
    }

    var isEmpty: Bool {
        results.isEmpty && !isSearching && !searchQuery.isEmpty
    }

    var isInitialState: Bool {
        results.isEmpty && searchQuery.isEmpty && !isSearching
    }

    var statusText: String {
        if let total = totalItemCount {
            return "\(results.count) of \(total) results"
        } else if !results.isEmpty {
            return "\(results.count) results"
        } else {
            return ""
        }
    }
}
