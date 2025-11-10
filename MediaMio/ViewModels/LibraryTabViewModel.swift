//
//  LibraryTabViewModel.swift
//  MediaMio
//
//  View model for the Library tab with category switching (Movies/TV Shows)
//

import Foundation
import Combine

@MainActor
class LibraryTabViewModel: ObservableObject {
    @Published var selectedCategory: LibraryCategory = .movies
    @Published var libraries: [Library] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Child view models for each category
    @Published var moviesViewModel: LibraryViewModel?
    @Published var tvShowsViewModel: LibraryViewModel?

    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    var currentViewModel: LibraryViewModel? {
        switch selectedCategory {
        case .movies:
            return moviesViewModel
        case .tvShows:
            return tvShowsViewModel
        }
    }

    init(
        contentService: ContentService,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator? = nil
    ) {
        self.contentService = contentService
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator
    }

    // MARK: - Load Libraries

    func loadLibraries() async {
        guard !isLoading else { return }

        print("📚 Loading libraries for Library tab")
        isLoading = true
        errorMessage = nil

        do {
            libraries = try await contentService.getLibraries()

            // Create view models for each category
            await createCategoryViewModels()

            print("✅ Loaded \(libraries.count) libraries")
        } catch {
            print("❌ Failed to load libraries: \(error)")
            errorMessage = "Failed to load libraries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Category Switching

    func selectCategory(_ category: LibraryCategory) {
        guard category != selectedCategory else { return }

        print("🔄 Switching to category: \(category.displayName)")
        selectedCategory = category
    }

    // MARK: - Private Methods

    private func createCategoryViewModels() async {
        // Movies
        if let moviesLibrary = LibraryCategory.movies.matchingLibrary(from: libraries) {
            let section = ContentSection(
                title: moviesLibrary.name,
                items: [],
                type: .library(id: moviesLibrary.id, name: moviesLibrary.name)
            )

            moviesViewModel = LibraryViewModel(
                section: section,
                contentService: contentService,
                authService: authService,
                navigationCoordinator: navigationCoordinator
            )

            print("✅ Created Movies view model for library: \(moviesLibrary.name)")
        } else {
            print("⚠️ No Movies library found")
        }

        // TV Shows
        if let tvLibrary = LibraryCategory.tvShows.matchingLibrary(from: libraries) {
            let section = ContentSection(
                title: tvLibrary.name,
                items: [],
                type: .library(id: tvLibrary.id, name: tvLibrary.name)
            )

            tvShowsViewModel = LibraryViewModel(
                section: section,
                contentService: contentService,
                authService: authService,
                navigationCoordinator: navigationCoordinator
            )

            print("✅ Created TV Shows view model for library: \(tvLibrary.name)")
        } else {
            print("⚠️ No TV Shows library found")
        }
    }
}
