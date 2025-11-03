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

    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var currentStartIndex: Int = 0
    private let pageSize: Int = 50
    private var hasMoreContent: Bool = true
    private var totalItemCount: Int?

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
