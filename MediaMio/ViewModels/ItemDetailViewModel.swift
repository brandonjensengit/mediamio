//
//  ItemDetailViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class ItemDetailViewModel: ObservableObject {
    @Published var item: MediaItem
    @Published var detailedItem: MediaItem?
    @Published var similarItems: [MediaItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: JellyfinAPIClient
    private let authService: AuthenticationService
    weak var navigationCoordinator: NavigationCoordinator?
    weak var navigationManager: NavigationManager?

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    private var userId: String? {
        authService.currentSession?.user.id
    }

    init(
        item: MediaItem,
        apiClient: JellyfinAPIClient,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator? = nil,
        navigationManager: NavigationManager? = nil
    ) {
        self.item = item
        self.apiClient = apiClient
        self.authService = authService
        self.navigationCoordinator = navigationCoordinator
        self.navigationManager = navigationManager
    }

    // MARK: - Load Content

    func loadDetails() async {
        guard let userId = userId else {
            print("❌ No userId available")
            errorMessage = "Not authenticated"
            return
        }

        print("📄 Starting loadDetails for: \(item.name) (id: \(item.id))")
        isLoading = true
        errorMessage = nil

        do {
            print("📄 Calling API getItemDetails...")

            // Load detailed item info
            let details = try await apiClient.getItemDetails(userId: userId, itemId: item.id)
            print("✅ Loaded detailed item: \(details.name)")
            print("   - Has overview: \(details.overview != nil)")
            print("   - Has genres: \(details.genres != nil), count: \(details.genres?.count ?? 0)")
            print("   - Has studios: \(details.studios != nil), count: \(details.studios?.count ?? 0)")
            print("   - Has backdrop: \(details.imageTags?.backdrop != nil)")

            self.detailedItem = details

            // Load similar items
            print("📄 Loading similar items...")
            if let similar = try? await apiClient.getSimilarItems(userId: userId, itemId: item.id, limit: 12) {
                self.similarItems = similar.items
                print("✅ Loaded \(similar.items.count) similar items")
            } else {
                print("⚠️ No similar items found")
            }

            isLoading = false

        } catch {
            print("❌ Failed to load item details: \(error)")
            if let urlError = error as? URLError {
                print("   URLError code: \(urlError.code)")
            }
            errorMessage = "Failed to load details: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Actions

    func playItem() {
        print("▶️ Play: \(item.name)")

        // Use NavigationManager if available (new tab-based navigation)
        if let navManager = navigationManager {
            navManager.playItem(displayItem)
        }
        // Will be fully implemented in Phase 5 (Video Player)
    }

    func toggleFavorite() {
        print("❤️ Toggle favorite: \(item.name)")
        // Will be implemented in future phase
    }

    func selectSimilarItem(_ item: MediaItem) {
        print("📺 Selected similar item: \(item.name)")

        // Use NavigationManager if available (new tab-based navigation)
        if let navManager = navigationManager {
            navManager.showDetail(for: item)
        } else {
            // Fallback to old navigation coordinator
            navigationCoordinator?.navigate(to: item)
        }
    }

    // MARK: - Computed Properties

    var displayItem: MediaItem {
        detailedItem ?? item
    }

    var hasProgress: Bool {
        guard let userData = displayItem.userData,
              let position = userData.playbackPositionTicks,
              let total = displayItem.runTimeTicks else {
            return false
        }

        let progress = Double(position) / Double(total) * 100.0
        return progress > 1.0 && progress < 95.0
    }

    var progressPercentage: Double {
        guard let userData = displayItem.userData,
              let position = userData.playbackPositionTicks,
              let total = displayItem.runTimeTicks else {
            return 0
        }

        return (Double(position) / Double(total)) * 100.0
    }

    var isFavorite: Bool {
        displayItem.userData?.isFavorite ?? false
    }

    var genresText: String? {
        guard let genres = displayItem.genres, !genres.isEmpty else {
            return nil
        }
        return genres.joined(separator: ", ")
    }

    var studiosText: String? {
        guard let studios = displayItem.studios, !studios.isEmpty else {
            return nil
        }
        return studios.map { $0.name }.joined(separator: ", ")
    }
}
