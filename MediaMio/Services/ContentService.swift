//
//  ContentService.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class ContentService: ObservableObject {
    private let apiClient: JellyfinAPIClient
    private let authService: AuthenticationService

    init(apiClient: JellyfinAPIClient, authService: AuthenticationService) {
        self.apiClient = apiClient
        self.authService = authService
    }

    // MARK: - Convenience Properties

    private var userId: String? {
        authService.currentSession?.user.id
    }

    private var baseURL: String {
        apiClient.baseURL
    }

    // MARK: - Home Screen Content

    /// Load all sections for the home screen.
    ///
    /// Continue Watching + each library's first page (sorted most-recent-first)
    /// are fetched in parallel. The returned section order is: Continue
    /// Watching, then libraries in server order. The dedicated "Recently
    /// Added" section was removed because each library now surfaces its own
    /// recent additions at the top of its row — one "recently added" stream
    /// across all content was redundant once per-library sort flipped to
    /// `DateCreated Descending`.
    func loadHomeContent() async throws -> [ContentSection] {
        guard userId != nil else {
            throw APIError.authenticationFailed
        }

        async let continueWatchingTask = try? await loadContinueWatching()
        async let librariesTask = try await getLibraries()

        let continueWatching = await continueWatchingTask
        let libraries = try await librariesTask

        let homeLibraries = libraries.filter { $0.isMovieLibrary || $0.isTVLibrary }

        // Fan out per-library section loads in parallel, preserving server order.
        let librarySections: [ContentSection] = await withTaskGroup(of: (Int, ContentSection?).self) { group in
            for (index, library) in homeLibraries.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { return (index, nil) }
                    let section = try? await self.loadLibrarySection(library: library)
                    return (index, section)
                }
            }
            var indexed: [(Int, ContentSection)] = []
            for await (index, section) in group {
                if let section = section {
                    indexed.append((index, section))
                }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        var sections: [ContentSection] = []
        if let cw = continueWatching, !cw.items.isEmpty {
            sections.append(cw)
        }
        sections.append(contentsOf: librarySections)
        return sections
    }

    /// Load continue watching section
    func loadContinueWatching() async throws -> ContentSection {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let controls = ParentalControlsConfig.current
        let response = try await apiClient.getContinueWatching(
            userId: userId,
            limit: 12,
            maxOfficialRating: controls.jellyfinMaxRating
        )

        return ContentSection(
            title: "Continue Watching",
            items: controls.filter(response.items),
            type: .continueWatching
        )
    }

    /// Load recently added section
    func loadRecentlyAdded() async throws -> ContentSection {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let controls = ParentalControlsConfig.current
        let items = try await apiClient.getRecentlyAdded(
            userId: userId,
            limit: 16,
            maxOfficialRating: controls.jellyfinMaxRating
        )

        return ContentSection(
            title: "Recently Added",
            items: controls.filter(items),
            type: .recentlyAdded
        )
    }

    /// Load a library section (first N items)
    func loadLibrarySection(library: Library, limit: Int = 20) async throws -> ContentSection {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let itemTypes: [String]
        if library.isMovieLibrary {
            itemTypes = ["Movie"]
        } else if library.isTVLibrary {
            itemTypes = ["Series"]
        } else {
            itemTypes = []
        }

        let controls = ParentalControlsConfig.current
        // Sort by DateCreated descending so the most recently added items
        // surface first on the Home carousel. SortName is included as a
        // tie-breaker — without it, items added in the same batch fall into
        // server-insertion order which reads as random.
        let response = try await apiClient.getLibraryItems(
            userId: userId,
            parentId: library.id,
            includeItemTypes: itemTypes,
            maxOfficialRating: controls.jellyfinMaxRating,
            limit: limit,
            sortBy: "DateCreated,SortName",
            sortOrder: "Descending"
        )

        return ContentSection(
            title: library.name,
            items: controls.filter(response.items),
            type: .library(id: library.id, name: library.name)
        )
    }

    // MARK: - Libraries

    /// Get all user libraries
    func getLibraries() async throws -> [Library] {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let response = try await apiClient.getLibraries(userId: userId)
        return response.items
    }

    // MARK: - Library Content

    /// Load full library content with pagination
    func loadLibraryContent(
        libraryId: String,
        itemTypes: [String]? = nil,
        filters: LibraryFilters? = nil,
        nameStartsWith: String? = nil,
        limit: Int = 50,
        startIndex: Int = 0,
        sortBy: String? = nil,
        sortOrder: String? = nil
    ) async throws -> ItemsResponse {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        // Extract filter parameters
        var genres: [String]?
        var years: [Int]?
        var minRating: Double?
        var isPlayed: Bool?

        if let filters = filters {
            if !filters.selectedGenres.isEmpty {
                genres = filters.selectedGenres.map { $0.rawValue }
            }
            if let yearRange = filters.yearRange {
                var yearsList: [Int] = []
                if let start = yearRange.start {
                    yearsList.append(start)
                }
                if let end = yearRange.end, end != yearRange.start {
                    yearsList.append(end)
                }
                years = yearsList.isEmpty ? nil : yearsList
            }
            if filters.minimumRating > 0 {
                minRating = filters.minimumRating
            }
            if filters.showWatched != filters.showUnwatched {
                isPlayed = filters.showWatched
            }
        }

        let controls = ParentalControlsConfig.current
        let response = try await apiClient.getLibraryItems(
            userId: userId,
            parentId: libraryId,
            includeItemTypes: itemTypes,
            genres: genres,
            years: years,
            minRating: minRating,
            isPlayed: isPlayed,
            nameStartsWith: nameStartsWith,
            maxOfficialRating: controls.jellyfinMaxRating,
            limit: limit,
            startIndex: startIndex,
            sortBy: sortBy,
            sortOrder: sortOrder
        )
        return ItemsResponse(
            items: controls.filter(response.items),
            totalRecordCount: response.totalRecordCount,
            startIndex: response.startIndex
        )
    }

    // MARK: - Search

    /// Search for items
    func searchItems(
        searchTerm: String,
        includeItemTypes: [String]? = nil,
        limit: Int = 50,
        startIndex: Int = 0
    ) async throws -> ItemsResponse {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let controls = ParentalControlsConfig.current
        let response = try await apiClient.searchItems(
            userId: userId,
            searchTerm: searchTerm,
            includeItemTypes: includeItemTypes,
            maxOfficialRating: controls.jellyfinMaxRating,
            limit: limit,
            startIndex: startIndex
        )
        return ItemsResponse(
            items: controls.filter(response.items),
            totalRecordCount: response.totalRecordCount,
            startIndex: response.startIndex
        )
    }

    // MARK: - Item Details

    /// Get detailed information for a media item
    func getItemDetails(itemId: String) async throws -> MediaItem {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        return try await apiClient.getItemDetails(userId: userId, itemId: itemId)
    }

    // MARK: - Images

    /// Build image URL for a media item
    func getImageURL(for item: MediaItem, imageType: ImageType, width: Int? = nil) -> String? {
        switch imageType {
        case .primary:
            return item.primaryImageURL(baseURL: baseURL, maxWidth: width ?? Constants.UI.posterImageMaxWidth)
        case .backdrop:
            return item.backdropImageURL(baseURL: baseURL, maxWidth: width ?? Constants.UI.backdropImageMaxWidth)
        case .thumb:
            return item.thumbImageURL(baseURL: baseURL, maxWidth: width ?? Constants.UI.thumbImageMaxWidth)
        }
    }

    enum ImageType {
        case primary
        case backdrop
        case thumb
    }
}
