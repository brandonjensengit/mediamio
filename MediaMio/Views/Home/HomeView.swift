//
//  HomeView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI
import Combine

// MARK: - Item Detail Wrapper

struct ItemDetailViewWrapper: View {
    let item: MediaItem
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    var navigationManager: NavigationManager? = nil
    @StateObject private var viewModel: ItemDetailViewModel

    init(
        item: MediaItem,
        authService: AuthenticationService,
        coordinator: NavigationCoordinator,
        navigationManager: NavigationManager? = nil,
        env: AppEnvironment
    ) {
        self.item = item
        self.authService = authService
        self.coordinator = coordinator
        self.navigationManager = navigationManager

        // `env.apiClient`'s session fields are kept in sync by AppEnvironment;
        // no more per-site `JellyfinAPIClient` construction.
        _viewModel = StateObject(wrappedValue: ItemDetailViewModel(
            item: item,
            apiClient: env.apiClient,
            authService: authService,
            navigationCoordinator: coordinator,
            navigationManager: navigationManager
        ))
    }

    var body: some View {
        ItemDetailView(viewModel: viewModel)
    }
}

// MARK: - Library View Wrapper

struct LibraryViewWrapper: View {
    let section: ContentSection
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    @StateObject private var viewModel: LibraryViewModel

    init(section: ContentSection, authService: AuthenticationService, coordinator: NavigationCoordinator, env: AppEnvironment) {
        self.section = section
        self.authService = authService
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: LibraryViewModel(
            section: section,
            contentService: env.contentService,
            authService: authService,
            navigationCoordinator: coordinator
        ))
    }

    var body: some View {
        LibraryView(viewModel: viewModel)
    }
}

// MARK: - Search View Wrapper

struct SearchViewWrapper: View {
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    @StateObject private var viewModel: SearchViewModel

    init(authService: AuthenticationService, coordinator: NavigationCoordinator, env: AppEnvironment) {
        self.authService = authService
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: SearchViewModel(
            contentService: env.contentService,
            authService: authService,
            navigationCoordinator: coordinator
        ))
    }

    var body: some View {
        SearchView(
            viewModel: viewModel,
            authService: authService,
            coordinator: coordinator
        )
    }
}

// MARK: - Navigation Coordinator

enum NavigationDestination: Hashable {
    case search
    case settings
}

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()

    func navigate(to item: MediaItem) {
        print("🧭 Navigating to: \(item.name)")
        navigationPath.append(item)
    }

    func navigate(to section: ContentSection) {
        print("🧭 Navigating to section: \(section.title)")
        navigationPath.append(section)
    }

    func navigateToSearch() {
        print("🧭 Navigating to: Search")
        navigationPath.append(NavigationDestination.search)
    }

    func navigateToSettings() {
        print("🧭 Navigating to: Settings")
        navigationPath.append(NavigationDestination.settings)
    }
}

// MARK: - Home Content View

struct HomeContentView: View {
    @ObservedObject var viewModel: HomeViewModel
    var navigationManager: NavigationManager? = nil
    @State private var hasSetInitialScroll = false

    // MARK: - Focus Management
    @StateObject private var focusManager = FocusManager()
    @FocusState private var focusedField: String?
    @Namespace private var focusNamespace

    private func isLibrarySection(_ section: ContentSection) -> Bool {
        if case .library = section.type {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && !viewModel.hasContent {
                // Initial loading state — show the Home shape as skeletons instead
                // of a black screen so the first-paint perceived latency is lower.
                HomeSkeletonView()
            } else if let error = viewModel.errorMessage {
                // Error state
                ErrorView(message: error) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            } else if viewModel.isEmpty {
                EmptyStateView(
                    systemImage: "film.stack",
                    title: "No Content Yet",
                    message: "Add some media to your Jellyfin libraries to get started"
                )
            } else {
                // Content
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Invisible anchor at the very top
                            Color.clear
                                .frame(height: 1)
                                .id("top")

                            // Hero Banner with auto-rotation (Netflix-style)
                            // With focus tracking for Netflix-style navigation
                            if viewModel.featuredItems.count > 1 {
                                HeroBannerRotating(
                                    items: viewModel.featuredItems,
                                    baseURL: viewModel.baseURL,
                                    onPlay: { viewModel.playItem($0) },
                                    onInfo: { viewModel.showItemDetails($0) }
                                )
                                .id("hero")
                                .focused($focusedField, equals: "hero")
                            } else if let featured = viewModel.featuredItem {
                                // Single item fallback
                                HeroBanner(
                                    item: featured,
                                    baseURL: viewModel.baseURL,
                                    onPlay: { viewModel.playItem(featured) },
                                    onInfo: { viewModel.showItemDetails(featured) }
                                )
                                .id("hero")
                                .focused($focusedField, equals: "hero")
                            }

                            // Content Sections with Netflix-level focus memory
                            VStack(spacing: Constants.UI.sectionSpacing) {
                                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                                    // Only show "See All" for library sections (Movies, TV Shows, etc)
                                    // Hide for Continue Watching and Recently Added
                                    ContentRow(
                                        section: section,
                                        baseURL: viewModel.baseURL,
                                        rowIndex: index,
                                        navigationManager: navigationManager,
                                        focusManager: focusManager,
                                        onItemSelect: { viewModel.selectItem($0) },
                                        onSeeAll: isLibrarySection(section)
                                            ? { viewModel.showSeeAll(for: section) }
                                            : nil
                                    )
                                    .id("section-\(index)")
                                    .focused($focusedField, equals: "row-\(index)")
                                }
                            }
                            .padding(.top, 40)
                            .padding(.bottom, 60)
                        }
                        .onAppear {
                            // Scroll to the hero once on initial appearance.
                            // The previous implementation fired six `scrollTo`
                            // calls on a 0.1s–1.8s ramp to "fight the focus
                            // system" while three parallel focus trackers
                            // raced. With FocusManager demoted and
                            // FocusGuideViewController gone, a single
                            // deterministic scroll is enough — the focus
                            // engine then takes over and lands on the hero.
                            guard !hasSetInitialScroll else { return }
                            hasSetInitialScroll = true
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .task {
            // Load content when view appears
            await viewModel.loadContent()
        }
    }
}

// MARK: - Empty State

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundColor(.red.opacity(0.8))

            VStack(spacing: 12) {
                Text("Something Went Wrong")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            FocusableButton(title: "Try Again", style: .primary) {
                onRetry()
            }
            .frame(width: 300)
        }
    }
}

