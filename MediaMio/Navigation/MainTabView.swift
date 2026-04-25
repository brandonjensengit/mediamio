//
//  MainTabView.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 1: Core Navigation Structure
//  Phase A refactor: hoist tab view-models so they survive tab switches.
//

import SwiftUI

/// Top-level tab container.
///
/// All shared services and per-tab view models live here as `@StateObject`s so
/// that switching tabs (or briefly destroying inner tab views) cannot lose
/// scroll, focus, or in-flight load state. The previous implementation
/// re-built each VM lazily inside its tab via `@State viewModel: VM?`, which
/// reset to `nil` whenever the tab subview was torn down.
struct MainTabView: View {
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var homeCoordinator = NavigationCoordinator()
    @StateObject private var libraryCoordinator = NavigationCoordinator()

    @ObservedObject private var env: AppEnvironment

    init(env: AppEnvironment, appState: AppState) {
        self.env = env
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            contentService: env.contentService,
            authService: env.authService,
            apiClient: env.apiClient,
            navigationManager: nil,
            appState: appState
        ))
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(
            contentService: env.contentService,
            authService: env.authService
        ))
    }

    /// Handles a tap on a tab chip. Always pops that tab's NavigationStack
    /// to root so the user reliably gets "clean tab root" — matches the
    /// common tvOS/iOS convention where tapping the selected tab re-roots.
    /// `selectedTab` has already been flipped by TopNavBar's inline action
    /// before this fires.
    private func handleTabTap(_ tab: Tab) {
        switch tab {
        case .home:     homeCoordinator.navigationPath = NavigationPath()
        case .library:  libraryCoordinator.navigationPath = NavigationPath()
        case .search, .settings:
            // Search and Settings still use older NavigationLink(destination:)
            // push patterns that aren't bound to a coordinator path here —
            // their stacks reset via the system when their NavigationStack
            // re-mounts. No-op for now.
            break
        }
    }

    /// Returns the Menu-button action for the current state, or nil to let
    /// the system do its default. Three cases:
    ///   1. A pushed view is on screen → `nil` so the NavigationStack pops.
    ///   2. No pushed view, tab != Home → switch to Home.
    ///   3. No pushed view, tab == Home → `nil` so the system exits the app.
    private var menuAction: (() -> Void)? {
        if navigationManager.pushedViewCount > 0 {
            return nil // let NavigationStack pop
        }
        if navigationManager.selectedTab != .home {
            return { navigationManager.selectedTab = .home }
        }
        return nil
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TopNavBar(
                    selectedTab: $navigationManager.selectedTab,
                    onTabTap: { tab in handleTabTap(tab) }
                )
                .environmentObject(env.authService)

                // All four tabs stay mounted so scroll position, focus
                // memory, and in-flight loads survive tab switches (same
                // contract tvOS's native TabView provides). `.disabled`
                // on hidden tabs removes them from the focus engine.
                ZStack {
                    HomeTabView(viewModel: homeViewModel, coordinator: homeCoordinator)
                        .opacity(navigationManager.selectedTab == .home ? 1 : 0)
                        .disabled(navigationManager.selectedTab != .home)

                    SearchTabView(viewModel: searchViewModel)
                        .opacity(navigationManager.selectedTab == .search ? 1 : 0)
                        .disabled(navigationManager.selectedTab != .search)

                    LibraryTabViewWrapper(contentService: env.contentService, coordinator: libraryCoordinator)
                        .opacity(navigationManager.selectedTab == .library ? 1 : 0)
                        .disabled(navigationManager.selectedTab != .library)

                    SettingsTabView()
                        .opacity(navigationManager.selectedTab == .settings ? 1 : 0)
                        .disabled(navigationManager.selectedTab != .settings)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Tab-level Menu handling, three-tier:
        //   1. Current tab's NavigationStack is pushed → pop one level.
        //   2. Stack is at root AND tab != Home → switch to Home.
        //   3. Stack is at root AND tab == Home → `perform: nil`, letting
        //      the system do its default exit to the tvOS home screen.
        // We handle pop manually (rather than letting NavigationStack do it)
        // because .onExitCommand at this level intercepts Menu before the
        // inner NavigationStacks see it.
        .onExitCommand(perform: menuAction)
        .environmentObject(navigationManager)
        .accentColor(Constants.Colors.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            // Wire navigationManager into VMs that need it. Done here (not in
            // init) because both objects are @StateObjects on this view and
            // can't reference each other at init time.
            homeViewModel.navigationManager = navigationManager
            homeViewModel.navigationCoordinator = homeCoordinator
        }
        // Present detail view full-screen. We deliberately avoid `.sheet` /
        // `.presentationDetents([.large])` because tvOS renders that as an
        // inset card with rounded corners — leaves the parent tab bleeding
        // through on the sides and constrains the 700pt backdrop header.
        .fullScreenCover(item: $navigationManager.presentedItem) { item in
            ItemDetailSheetWrapper(item: item)
                .environmentObject(env.authService)
                .environmentObject(env)
                .environmentObject(navigationManager)
        }
        // Root-level player cover — fires on Play taps from Hero /
        // Continue Watching / Library rows, where no Detail sheet is open.
        // The sibling cover inside `ItemDetailSheetWrapper` handles the
        // Detail → Play path; the two bind to different flags so tvOS
        // routes each present to the correct modal context.
        .fullScreenCover(
            isPresented: $navigationManager.showingPlayerAtRoot,
            onDismiss: { navigationManager.handlePlayerDismissed() }
        ) {
            if let item = navigationManager.currentPlayerItem {
                VideoPlayerView(
                    item: item,
                    authService: env.authService,
                    startPositionTicks: navigationManager.currentPlayerStartTicks
                )
                .environmentObject(navigationManager)
            }
        }
    }
}

// MARK: - Home Tab Wrapper

struct HomeTabView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var coordinator: NavigationCoordinator
    @EnvironmentObject var navigationManager: NavigationManager

    var body: some View {
        // Coordinator is held (not used) so the tab-tap handler in
        // MainTabView can reset its path uniformly with Library. Home
        // currently has no pushable destinations — items open via
        // `fullScreenCover`, and "See All" was removed in favor of
        // using the Library tab for deeper browsing.
        NavigationStack(path: $coordinator.navigationPath) {
            HomeContentView(
                viewModel: viewModel,
                navigationManager: navigationManager
            )
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Search Tab Wrapper

struct SearchTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack {
            SearchView(
                viewModel: viewModel,
                authService: authService,
                coordinator: coordinator,
                navigationManager: navigationManager
            )
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Library Tab Wrapper

struct LibraryTabViewWrapper: View {
    @ObservedObject var contentService: ContentService
    @ObservedObject var coordinator: NavigationCoordinator
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        NavigationStack {
            LibraryTabView(
                contentService: contentService,
                authService: authService,
                navigationCoordinator: coordinator
            )
            .navigationBarHidden(true)
        }
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(authService)
                .navigationBarHidden(true)
        }
    }
}


// MARK: - Item Detail Sheet Wrapper

struct ItemDetailSheetWrapper: View {
    let item: MediaItem
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var viewModel: ItemDetailViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ItemDetailView(viewModel: vm)
            } else {
                LoadingView(message: "Loading details...", showLogo: false)
                    .onAppear {
                        initializeViewModel()
                    }
            }
        }
        // Sheet-level player cover — when Play is tapped inside this Detail
        // sheet, the player presents on top without dismissing the sheet.
        // Menu-back from the player returns to this sheet; another Menu
        // dismisses the sheet itself and lands on Home.
        .fullScreenCover(
            isPresented: $navigationManager.showingPlayerOverDetail,
            onDismiss: { navigationManager.handlePlayerDismissed() }
        ) {
            if let item = navigationManager.currentPlayerItem {
                VideoPlayerView(
                    item: item,
                    authService: env.authService,
                    startPositionTicks: navigationManager.currentPlayerStartTicks
                )
                .environmentObject(navigationManager)
            }
        }
    }

    private func initializeViewModel() {
        guard viewModel == nil, env.authService.currentSession != nil else { return }
        viewModel = ItemDetailViewModel(
            item: item,
            apiClient: env.apiClient,
            authService: env.authService,
            navigationCoordinator: nil,
            navigationManager: navigationManager
        )
    }
}

