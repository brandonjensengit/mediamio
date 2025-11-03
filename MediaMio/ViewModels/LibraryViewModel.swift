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

    private let section: ContentSection
    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    private var currentStartIndex: Int = 0
    private let pageSize: Int = 50
    private var hasMoreContent: Bool = true
    private var totalItemCount: Int?

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
    }

    // MARK: - Sort Options

    enum SortOption: String, CaseIterable, Identifiable {
        case alphabetical = "Name"
        case dateAdded = "DateCreated"
        case releaseDate = "PremiereDate"
        case rating = "CommunityRating"
        case random = "Random"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .alphabetical: return "A-Z"
            case .dateAdded: return "Date Added"
            case .releaseDate: return "Release Date"
            case .rating: return "Rating"
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
            case .dateAdded, .rating:
                return "Descending"
            case .random:
                return "Ascending"
            }
        }
    }

    // MARK: - Load Content

    func loadContent() async {
        guard !isLoading else { return }

        print("📚 Loading library content: \(title)")
        isLoading = true
        errorMessage = nil
        currentStartIndex = 0
        hasMoreContent = true

        await loadItems()

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMoreContent else { return }

        print("📚 Loading more items (startIndex: \(currentStartIndex))")
        isLoadingMore = true

        await loadItems()

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
                limit: pageSize,
                startIndex: currentStartIndex,
                sortBy: sortOption.sortBy,
                sortOrder: sortOption.sortOrder
            )

            if currentStartIndex == 0 {
                // First load - replace all items
                items = response.items
            } else {
                // Pagination - append items
                items.append(contentsOf: response.items)
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

            print("✅ Loaded \(response.items.count) items (total: \(items.count), hasMore: \(hasMoreContent))")

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
        await loadContent()
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
        if let total = totalItemCount {
            return "\(items.count) of \(total) items"
        } else {
            return "\(items.count) items"
        }
    }
}
