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
    @StateObject private var libraryCoordinator = NavigationCoordinator()

    @ObservedObject private var env: AppEnvironment

    init(env: AppEnvironment, appState: AppState) {
        self.env = env
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            contentService: env.contentService,
            authService: env.authService,
            navigationManager: nil,
            appState: appState
        ))
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(
            contentService: env.contentService,
            authService: env.authService
        ))
    }

    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            HomeTabView(viewModel: homeViewModel)
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            SearchTabView(viewModel: searchViewModel)
                .tabItem {
                    Label(Tab.search.title, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

            LibraryTabViewWrapper(contentService: env.contentService, coordinator: libraryCoordinator)
                .tabItem {
                    Label(Tab.library.title, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

            SettingsTabView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .environmentObject(navigationManager)
        .accentColor(Color(hex: "667eea")) // MediaMio brand color
        .preferredColorScheme(.dark)
        .onAppear {
            // Wire navigationManager into VMs that need it. Done here (not in
            // init) because both objects are @StateObjects on this view and
            // can't reference each other at init time.
            homeViewModel.navigationManager = navigationManager
        }
        // Present detail view as sheet
        .sheet(item: $navigationManager.presentedItem) { item in
            ItemDetailSheetWrapper(item: item)
                .environmentObject(env.authService)
                .environmentObject(env)
                .environmentObject(navigationManager)
        }
        // Present video player as full screen cover
        .fullScreenCover(isPresented: $navigationManager.showingPlayer) {
            if let item = navigationManager.currentPlayerItem {
                VideoPlayerView(item: item, authService: env.authService)
                    .environmentObject(navigationManager)
            }
        }
    }
}

// MARK: - Home Tab Wrapper

struct HomeTabView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var navigationManager: NavigationManager

    var body: some View {
        NavigationStack {
            HomeContentView(
                viewModel: viewModel,
                isSidebarVisible: .constant(false),
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
                    .presentationDetents([.large])
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(30)
            } else {
                LoadingView(message: "Loading details...", showLogo: false)
                    .presentationDetents([.large])
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(30)
                    .onAppear {
                        initializeViewModel()
                    }
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

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
