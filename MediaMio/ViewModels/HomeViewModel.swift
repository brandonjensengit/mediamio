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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedItem: MediaItem?

    private let contentService: ContentService
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    init(contentService: ContentService, authService: AuthenticationService, navigationCoordinator: NavigationCoordinator? = nil) {
        self.contentService = contentService
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator
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

            isLoading = false

        } catch {
            print("❌ Failed to load home content: \(error)")
            errorMessage = "Failed to load content: \(error.localizedDescription)"
            isLoading = false
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
        navigationCoordinator?.navigate(to: item)
    }

    func playItem(_ item: MediaItem) {
        print("▶️ Play: \(item.name)")
        // Will be implemented in Phase 4 (Video Playback)
        selectedItem = item
        navigationCoordinator?.navigate(to: item)
    }

    func showItemDetails(_ item: MediaItem) {
        print("ℹ️ Show details for: \(item.name)")
        selectedItem = item
        navigationCoordinator?.navigate(to: item)
    }

    func showSeeAll(for section: ContentSection) {
        print("👀 See all for: \(section.title)")
        // Will be implemented in Phase 3 (Library browsing)
    }

    // MARK: - Helpers

    var hasContent: Bool {
        !sections.isEmpty
    }

    var isEmpty: Bool {
        sections.isEmpty && !isLoading
    }
}
