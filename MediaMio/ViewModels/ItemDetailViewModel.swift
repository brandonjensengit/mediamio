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
    @Published var seasons: [MediaItem] = []
    @Published var episodes: [MediaItem] = []
    @Published var selectedSeason: MediaItem?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Optimistic favorite state. `MediaItem` is a struct with `let` fields
    // so we cannot mutate UserData.isFavorite in place. Instead, we shadow
    // the server-decoded value until the next `loadDetails()` round-trips
    // the fresh UserData. Nil = "no pending override, use the server value".
    @Published private var isFavoriteOverride: Bool?
    @Published var isFavoriteBusy: Bool = false

    private let apiClient: JellyfinAPIClient
    private let authService: AuthenticationService
    private let settingsManager = SettingsManager()
    weak var navigationCoordinator: NavigationCoordinator?
    weak var navigationManager: NavigationManager?

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    /// URL to open this item in Jellyfin's web client on another device. Used
    /// by the QR-handoff sheet on Detail. Empty when we have no session (the
    /// Detail button is hidden in that case).
    var handoffURL: String {
        guard !baseURL.isEmpty else { return "" }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let targetId = (detailedItem ?? item).id
        return "\(trimmed)/web/index.html#/details?id=\(targetId)"
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
            DebugLog.verbose("❌ No userId available")
            errorMessage = "Not authenticated"
            return
        }

        DebugLog.verbose("📄 Starting loadDetails for: \(item.name) (id: \(item.id))")
        isLoading = true
        errorMessage = nil

        do {
            DebugLog.verbose("📄 Calling API getItemDetails...")

            // Load detailed item info
            let details = try await apiClient.getItemDetails(userId: userId, itemId: item.id)
            DebugLog.verbose("✅ Loaded detailed item: \(details.name)")
            DebugLog.verbose("   - Has overview: \(details.overview != nil)")
            DebugLog.verbose("   - Has genres: \(details.genres != nil), count: \(details.genres?.count ?? 0)")
            DebugLog.verbose("   - Has studios: \(details.studios != nil), count: \(details.studios?.count ?? 0)")
            DebugLog.verbose("   - Has backdrop: \(details.imageTags?.backdrop != nil)")

            self.detailedItem = details
            // Fresh UserData from server — discard any pending optimistic flip.
            self.isFavoriteOverride = nil

            // Load seasons if this is a Series
            if details.type == "Series" {
                DebugLog.verbose("📄 Loading seasons for series...")
                await loadSeasons()
            }

            // Load similar items
            DebugLog.verbose("📄 Loading similar items...")
            if let similar = try? await apiClient.getSimilarItems(userId: userId, itemId: item.id, limit: 12) {
                self.similarItems = similar.items
                DebugLog.verbose("✅ Loaded \(similar.items.count) similar items")
            } else {
                DebugLog.verbose("⚠️ No similar items found")
            }

            isLoading = false

        } catch {
            DebugLog.verbose("❌ Failed to load item details: \(error)")
            if let urlError = error as? URLError {
                DebugLog.verbose("   URLError code: \(urlError.code)")
            }
            errorMessage = "Failed to load details: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func loadSeasons() async {
        guard let userId = userId else { return }

        do {
            DebugLog.verbose("📺 Fetching seasons for series: \(item.id)")
            let response = try await apiClient.getSeasons(userId: userId, seriesId: item.id)
            self.seasons = response.items
            DebugLog.verbose("✅ Loaded \(response.items.count) seasons")

            // Auto-select first season and load its episodes
            if let firstSeason = seasons.first {
                await selectSeason(firstSeason)
            }
        } catch {
            DebugLog.verbose("❌ Failed to load seasons: \(error)")
        }
    }

    func selectSeason(_ season: MediaItem) async {
        selectedSeason = season
        await loadEpisodes(for: season)
    }

    func loadEpisodes(for season: MediaItem) async {
        guard let userId = userId else { return }

        do {
            DebugLog.verbose("📺 Fetching episodes for season: \(season.id)")
            let response = try await apiClient.getEpisodes(userId: userId, seriesId: item.id, seasonId: season.id)
            self.episodes = response.items
            DebugLog.verbose("✅ Loaded \(response.items.count) episodes")
        } catch {
            DebugLog.verbose("❌ Failed to load episodes: \(error)")
        }
    }

    func playEpisode(_ episode: MediaItem) {
        DebugLog.verbose("▶️ Play episode: \(episode.name)")
        navigationManager?.playItem(episode)
    }

    func playChapter(_ chapter: Chapter) {
        DebugLog.verbose("📖 Play chapter '\(chapter.displayName)' at \(chapter.formattedStart)")
        guard let navManager = navigationManager else {
            errorMessage = "Cannot start playback (navigation not configured)"
            return
        }
        navManager.playItem(displayItem, startPositionTicks: chapter.startPositionTicks)
    }

    // MARK: - Actions

    /// Launch the video player.
    /// - Parameter fromBeginning: When `true`, pass an explicit `0` start tick
    ///   to the player so it skips `userData.playbackPositionTicks` and
    ///   starts at 00:00. When `false` (default), the player's own resume
    ///   logic kicks in — auto-resumes if userData has progress, else plays
    ///   from start.
    func playItem(fromBeginning: Bool = false) {
        DebugLog.verbose("▶️ Play: \(displayItem.name)\(fromBeginning ? " (from beginning)" : "")")

        guard let navManager = navigationManager else {
            DebugLog.verbose("❌ playItem failed: NavigationManager is nil — Play button is unwired")
            errorMessage = "Cannot start playback (navigation not configured)"
            return
        }
        navManager.playItem(displayItem, startPositionTicks: fromBeginning ? 0 : nil)
    }

    /// Handle a Play-button tap, honoring the user's Resume Behavior setting.
    /// Returns `true` if the caller should present the Resume / Play-from-
    /// Beginning prompt; otherwise playback has already been started here.
    /// With no saved progress, always plays from the start (no prompt).
    func handlePlayButtonTapped() -> Bool {
        guard hasProgress else { playItem(); return false }
        switch ResumeBehavior(rawValue: settingsManager.resumeBehavior) ?? .alwaysAsk {
        case .alwaysAsk:
            return true                       // caller shows the dialog
        case .alwaysResume:
            playItem(); return false          // resume silently
        case .neverResume:
            playItem(fromBeginning: true); return false
        }
    }

    /// Human-readable resume-from label — "1h 20m" or "25m". Used in the
    /// Play confirmation dialog on items that already have progress so the
    /// Resume button communicates exactly where it'd resume from.
    var resumePositionLabel: String? {
        guard let userData = displayItem.userData,
              let position = userData.playbackPositionTicks,
              position > 0 else {
            return nil
        }
        let totalSeconds = position / 10_000_000
        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds % 3600) / 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    func toggleFavorite() {
        Task { await toggleFavoriteAsync() }
    }

    private func toggleFavoriteAsync() async {
        guard let userId = userId else {
            errorMessage = "Not authenticated"
            return
        }
        guard !isFavoriteBusy else { return }

        let currentValue = isFavorite
        let newValue = !currentValue

        DebugLog.verbose("❤️ Toggle favorite: \(displayItem.name) → \(newValue)")

        // Optimistic flip: the UI (heart icon + button label) re-renders now.
        isFavoriteOverride = newValue
        isFavoriteBusy = true
        defer { isFavoriteBusy = false }

        do {
            let itemId = displayItem.id
            _ = newValue
                ? try await apiClient.markFavorite(userId: userId, itemId: itemId)
                : try await apiClient.unmarkFavorite(userId: userId, itemId: itemId)
            // Success — leave the override in place until next loadDetails()
            // naturally refreshes the underlying UserData.
        } catch {
            DebugLog.verbose("❌ Favorite toggle failed: \(error)")
            isFavoriteOverride = currentValue
            errorMessage = "Couldn't update favorite: \(error.localizedDescription)"
        }
    }

    func selectSimilarItem(_ item: MediaItem) {
        DebugLog.verbose("📺 Selected similar item: \(item.name)")

        // Prefer pushing onto the detail sheet's own NavigationStack so the
        // similar item opens as a new detail page (drill-down; Menu-back pops
        // it). Reassigning `presentedItem` while the fullScreenCover is
        // already open just dismisses it and drops the user back on Home.
        if let coordinator = navigationCoordinator {
            coordinator.navigate(to: item)
        } else {
            navigationManager?.showDetail(for: item)
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
            DebugLog.verbose("📊 hasProgress=false for '\(displayItem.name)': userData=\(displayItem.userData != nil), position=\(displayItem.userData?.playbackPositionTicks != nil), total=\(displayItem.runTimeTicks != nil)")
            return false
        }

        let progress = Double(position) / Double(total) * 100.0
        let hasProgress = progress > 1.0 && progress < 95.0
        DebugLog.verbose("📊 hasProgress=\(hasProgress) for '\(displayItem.name)': position=\(position), total=\(total), progress=\(String(format: "%.1f", progress))%")
        return hasProgress
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
        // Pending optimistic flip wins over the (stale) decoded server value.
        if let override = isFavoriteOverride { return override }
        return displayItem.userData?.isFavorite ?? false
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
