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
    @EnvironmentObject var navigationManager: NavigationManager

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
            coordinator: coordinator,
            navigationManager: navigationManager
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
            } else if viewModel.allRowsHidden {
                AllRowsHiddenView()
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

                            // Hero removed — Continue Watching is the first
                            // thing the user sees. The VM still computes
                            // `featuredItems` cheaply, so re-introducing a
                            // hero later is a paste-back, not a rebuild.

                            // Content Sections with Netflix-level focus memory.
                            // `.focusSection()` groups all shelves into one
                            // focus container — a right-swipe from a hero
                            // CTA lands on the leftmost tile of the current
                            // row instead of jumping to a distant neighbor.
                            VStack(spacing: Constants.UI.sectionSpacing) {
                                ForEach(viewModel.sections, id: \.type.stableKey) { section in
                                    ContentRow(
                                        section: section,
                                        baseURL: viewModel.baseURL,
                                        rowKey: section.type.stableKey,
                                        navigationManager: navigationManager,
                                        focusManager: focusManager,
                                        onItemSelect: { viewModel.selectItem($0) },
                                        onContextAction: { item, action in
                                            viewModel.handleContextAction(action, for: item)
                                        }
                                    )
                                    .id("section-\(section.type.stableKey)")
                                    .focused($focusedField, equals: section.type.stableKey)
                                }
                            }
                            .focusSection()
                            .padding(.top, 40)
                            .padding(.bottom, 60)
                            .animation(.snappy, value: viewModel.sections.map(\.type.stableKey))
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

/// Shown when the user has hidden every Home row via the layout customizer.
/// Distinct copy from "No Content Yet" because the remediation is different
/// — they just need to unhide a row in Settings.
struct AllRowsHiddenView: View {
    @ObservedObject private var store = HomeLayoutStore.shared
    @FocusState private var isRestoreFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.slash")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 12) {
                Text("All Home Rows Are Hidden")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Restore a row to see content here.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            // Restore the most-recently-seen hidden row so the user can
            // recover with one click. Falls back to "Reset to Default" if
            // for some reason there are no hidden rows tracked.
            FocusableButton(title: "Restore First Hidden Row", style: .primary) {
                if let firstHidden = store.knownRows.first(where: {
                    store.preferences.hiddenRowKeys.contains($0.key)
                }) {
                    withAnimation(.snappy) { store.show(key: firstHidden.key) }
                } else {
                    withAnimation(.snappy) { store.reset() }
                }
            }
            .focused($isRestoreFocused)
            .frame(width: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isRestoreFocused = true
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    // Without this, focus stays on the Home nav chip when the error view
    // appears — the Try Again button is reachable geometrically but the
    // focus engine doesn't route to it from the top-tab row reliably
    // (reported stuck on physical Apple TV hardware). Grabbing focus on
    // appear makes the button actionable immediately.
    @FocusState private var isRetryFocused: Bool

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
            .focused($isRetryFocused)
            .frame(width: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // 100ms lets the view finish mounting before the focus engine
            // tries to find the target — assigning on the same frame as
            // `.onAppear` occasionally no-ops.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isRetryFocused = true
            }
        }
    }
}

