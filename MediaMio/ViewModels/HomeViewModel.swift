//
//  HomeViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

/// Long-press actions a `PosterCard` / `EpisodeThumbCard` can emit.
/// Scoped here (not in the card file) so both cards and the Home VM
/// share one vocabulary; the VM decides which API call each maps to.
enum PosterContextAction {
    case playFromBeginning
    case toggleWatched
    case toggleFavorite
    case goToSeries
    case removeFromResume
}

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
    private let apiClient: JellyfinAPIClient
    private let appState: AppState?
    weak var navigationCoordinator: NavigationCoordinator?
    weak var navigationManager: NavigationManager?

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    init(
        contentService: ContentService,
        authService: AuthenticationService,
        apiClient: JellyfinAPIClient,
        navigationCoordinator: NavigationCoordinator? = nil,
        navigationManager: NavigationManager? = nil,
        appState: AppState? = nil
    ) {
        self.contentService = contentService
        self.authService = authService
        self.apiClient = apiClient
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
            DebugLog.verbose("🏠 Loading home content...")

            // Load all sections
            let loadedSections = try await contentService.loadHomeContent()

            DebugLog.verbose("✅ Loaded \(loadedSections.count) sections")

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

            // Populate featured items for rotating hero banner (Netflix-style).
            // Prefer Continue Watching (first section) so returning users land
            // on something they're already invested in. Backfill from the
            // first library section — which is now sorted DateCreated desc,
            // so its prefix is effectively the most recent library additions.
            var heroItems: [MediaItem] = []

            if let firstSection = loadedSections.first {
                heroItems.append(contentsOf: firstSection.items.prefix(3))
            }

            if heroItems.count < 5 && loadedSections.count > 1 {
                let remaining = 5 - heroItems.count
                heroItems.append(contentsOf: loadedSections[1].items.prefix(remaining))
            }

            self.featuredItems = heroItems

            isLoading = false

            // Signal that content is loaded for splash screen
            appState?.contentLoaded = true

        } catch APIError.authenticationFailed {
            // Saved token is no good (expired or revoked server-side).
            // Drop the session — the root `MediaMioApp` routes to
            // `ServerEntryView` when `isAuthenticated` flips to false, so
            // the user sees a sign-in screen instead of a stuck error
            // page with an unreachable "Try Again" button.
            DebugLog.verbose("🔐 Home load 401 — clearing stale session")
            authService.clearSession()
            isLoading = false
            appState?.contentLoaded = true
        } catch {
            DebugLog.verbose("❌ Failed to load home content: \(error)")
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
        DebugLog.verbose("📺 Selected: \(item.name)")
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
        DebugLog.verbose("▶️ Play: \(item.name)")
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
        DebugLog.verbose("ℹ️ Show details for: \(item.name)")
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
        DebugLog.verbose("👀 See all for: \(section.title)")
        navigationCoordinator?.navigate(to: section)
    }

    // MARK: - Context Menu Actions

    /// Dispatches a poster long-press action to the right API call +
    /// navigation + refresh. Called from `ContentRow` via the
    /// `onContextAction` closure wired in `HomeContentView`.
    func handleContextAction(_ action: PosterContextAction, for item: MediaItem) {
        switch action {
        case .playFromBeginning:
            DebugLog.verbose("▶️ Play from beginning: \(item.name)")
            navigationManager?.playItem(item, startPositionTicks: 0)
        case .toggleWatched:
            Task { await toggleWatched(for: item) }
        case .toggleFavorite:
            Task { await toggleFavorite(for: item) }
        case .goToSeries:
            Task { await openSeries(for: item) }
        case .removeFromResume:
            Task { await removeFromResume(item) }
        }
    }

    private func toggleWatched(for item: MediaItem) async {
        guard let userId = authService.currentSession?.user.id else { return }
        let currentlyPlayed = item.userData?.played ?? false
        DebugLog.verbose("👁️ Toggle watched: \(item.name) → \(!currentlyPlayed)")
        do {
            _ = currentlyPlayed
                ? try await apiClient.unmarkPlayed(userId: userId, itemId: item.id)
                : try await apiClient.markPlayed(userId: userId, itemId: item.id)
            await refresh()
        } catch {
            DebugLog.verbose("❌ Toggle watched failed: \(error)")
            errorMessage = "Couldn't update watched state: \(error.localizedDescription)"
        }
    }

    private func toggleFavorite(for item: MediaItem) async {
        guard let userId = authService.currentSession?.user.id else { return }
        let currentlyFavorite = item.userData?.isFavorite ?? false
        DebugLog.verbose("❤️ Toggle favorite: \(item.name) → \(!currentlyFavorite)")
        do {
            _ = currentlyFavorite
                ? try await apiClient.unmarkFavorite(userId: userId, itemId: item.id)
                : try await apiClient.markFavorite(userId: userId, itemId: item.id)
            await refresh()
        } catch {
            DebugLog.verbose("❌ Toggle favorite failed: \(error)")
            errorMessage = "Couldn't update favorite: \(error.localizedDescription)"
        }
    }

    private func removeFromResume(_ item: MediaItem) async {
        // Jellyfin has no "hide from resume" endpoint — marking played
        // removes it from /Items/Resume and matches Netflix semantics.
        guard let userId = authService.currentSession?.user.id else { return }
        DebugLog.verbose("🗑️ Remove from Continue Watching: \(item.name)")
        do {
            _ = try await apiClient.markPlayed(userId: userId, itemId: item.id)
            await refresh()
        } catch {
            DebugLog.verbose("❌ Remove from resume failed: \(error)")
            errorMessage = "Couldn't remove from Continue Watching: \(error.localizedDescription)"
        }
    }

    private func openSeries(for item: MediaItem) async {
        guard let seriesId = item.seriesId,
              let userId = authService.currentSession?.user.id,
              let navManager = navigationManager else { return }
        DebugLog.verbose("📺 Go to series: \(item.seriesName ?? seriesId)")
        do {
            let series = try await apiClient.getItemDetails(userId: userId, itemId: seriesId)
            navManager.showDetail(for: series)
        } catch {
            DebugLog.verbose("❌ Go to series failed: \(error)")
            errorMessage = "Couldn't open series: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    var hasContent: Bool {
        !sections.isEmpty
    }

    var isEmpty: Bool {
        sections.isEmpty && !isLoading
    }
}
