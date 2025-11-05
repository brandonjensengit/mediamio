//
//  HomeViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var sections: [ContentSection] = []
    @Published var featuredItem: MediaItem?
    @Published var featuredItems: [MediaItem] = [] // Netflix-style rotating hero items
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedItem: MediaItem?

    private let contentService: ContentService
    private let authService: AuthenticationService
    private let appState: AppState?
    weak var navigationCoordinator: NavigationCoordinator?
    weak var navigationManager: NavigationManager?

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    init(
        contentService: ContentService,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator? = nil,
        navigationManager: NavigationManager? = nil,
        appState: AppState? = nil
    ) {
        self.contentService = contentService
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator
        self.navigationManager = navigationManager
        self.appState = appState
    }

    // MARK: - Load Content

    func loadContent() async {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("🏠 Loading home content...")

            // Load all sections
            let loadedSections = try await contentService.loadHomeContent()

            print("✅ Loaded \(loadedSections.count) sections")

            // Update UI
            self.sections = loadedSections

            // Set featured item (first item from continue watching or recently added)
            if let firstSection = loadedSections.first,
               let firstItem = firstSection.items.first {
                self.featuredItem = firstItem
            } else if loadedSections.count > 1,
                      let firstItem = loadedSections[1].items.first {
                self.featuredItem = firstItem
            }

            // Populate featured items for rotating hero banner (Netflix-style)
            // Get up to 5 items from continue watching and recently added
            var heroItems: [MediaItem] = []

            // Get items from first section (Continue Watching)
            if let firstSection = loadedSections.first {
                heroItems.append(contentsOf: firstSection.items.prefix(3))
            }

            // Add items from second section (Recently Added) if needed
            if heroItems.count < 5 && loadedSections.count > 1 {
                let remaining = 5 - heroItems.count
                heroItems.append(contentsOf: loadedSections[1].items.prefix(remaining))
            }

            self.featuredItems = heroItems

            isLoading = false

            // Signal that content is loaded for splash screen
            appState?.contentLoaded = true

        } catch {
            print("❌ Failed to load home content: \(error)")
            errorMessage = "Failed to load content: \(error.localizedDescription)"
            isLoading = false

            // Even on error, allow splash to dismiss
            appState?.contentLoaded = true
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadContent()
    }

    // MARK: - Content Actions

    func selectItem(_ item: MediaItem) {
        print("📺 Selected: \(item.name)")
        selectedItem = item

        // Use NavigationManager if available (new tab-based navigation)
        if let navManager = navigationManager {
            navManager.showDetail(for: item)
        } else {
            // Fallback to old navigation coordinator
            navigationCoordinator?.navigate(to: item)
        }
    }

    func playItem(_ item: MediaItem) {
        print("▶️ Play: \(item.name)")
        selectedItem = item

        // Use NavigationManager if available (new tab-based navigation)
        if let navManager = navigationManager {
            navManager.playItem(item)
        } else {
            // Fallback to old navigation coordinator
            navigationCoordinator?.navigate(to: item)
        }
    }

    func showItemDetails(_ item: MediaItem) {
        print("ℹ️ Show details for: \(item.name)")
        selectedItem = item

        // Use NavigationManager if available (new tab-based navigation)
        if let navManager = navigationManager {
            navManager.showDetail(for: item)
        } else {
            // Fallback to old navigation coordinator
            navigationCoordinator?.navigate(to: item)
        }
    }

    func showSeeAll(for section: ContentSection) {
        print("👀 See all for: \(section.title)")
        navigationCoordinator?.navigate(to: section)
    }

    // MARK: - Helpers

    var hasContent: Bool {
        !sections.isEmpty
    }

    var isEmpty: Bool {
        sections.isEmpty && !isLoading
    }
}
