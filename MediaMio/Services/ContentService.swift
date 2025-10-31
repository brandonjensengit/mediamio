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

    /// Load all sections for the home screen
    func loadHomeContent() async throws -> [ContentSection] {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        var sections: [ContentSection] = []

        // Load continue watching
        if let continueWatching = try? await loadContinueWatching(),
           !continueWatching.items.isEmpty {
            sections.append(continueWatching)
        }

        // Load recently added
        if let recentlyAdded = try? await loadRecentlyAdded(),
           !recentlyAdded.items.isEmpty {
            sections.append(recentlyAdded)
        }

        // Load library sections
        let libraries = try await apiClient.getLibraries(userId: userId)
        for library in libraries.items {
            // Only show movie and TV libraries on home screen
            if library.isMovieLibrary || library.isTVLibrary {
                if let librarySection = try? await loadLibrarySection(library: library) {
                    sections.append(librarySection)
                }
            }
        }

        return sections
    }

    /// Load continue watching section
    func loadContinueWatching() async throws -> ContentSection {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let response = try await apiClient.getContinueWatching(userId: userId, limit: 12)

        return ContentSection(
            title: "Continue Watching",
            items: response.items,
            type: .continueWatching
        )
    }

    /// Load recently added section
    func loadRecentlyAdded() async throws -> ContentSection {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        let items = try await apiClient.getRecentlyAdded(userId: userId, limit: 16)

        return ContentSection(
            title: "Recently Added",
            items: items,
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

        let response = try await apiClient.getLibraryItems(
            userId: userId,
            parentId: library.id,
            includeItemTypes: itemTypes,
            limit: limit,
            sortBy: "SortName"
        )

        return ContentSection(
            title: library.name,
            items: response.items,
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
        limit: Int = 50,
        startIndex: Int = 0
    ) async throws -> ItemsResponse {
        guard let userId = userId else {
            throw APIError.authenticationFailed
        }

        return try await apiClient.getLibraryItems(
            userId: userId,
            parentId: libraryId,
            includeItemTypes: itemTypes,
            limit: limit,
            startIndex: startIndex
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
        let itemId = item.id

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
