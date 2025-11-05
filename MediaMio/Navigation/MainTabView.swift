//
//  MainTabView.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 1: Core Navigation Structure
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    @StateObject private var navigationManager = NavigationManager()

    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            // Home Tab
            HomeTabView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            // Search Tab
            SearchTabView()
                .tabItem {
                    Label(Tab.search.title, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

            // Library Tab
            LibraryTabViewWrapper()
                .tabItem {
                    Label(Tab.library.title, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

            // Settings Tab
            SettingsTabView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .environmentObject(navigationManager)
        .accentColor(Color(hex: "667eea")) // MediaMio brand color
        .preferredColorScheme(.dark)
        // Present detail view as sheet
        .sheet(item: $navigationManager.presentedItem) { item in
            ItemDetailSheetWrapper(item: item)
                .environmentObject(authService)
                .environmentObject(navigationManager)
        }
        // Present video player as full screen cover
        .fullScreenCover(isPresented: $navigationManager.showingPlayer) {
            if let item = navigationManager.currentPlayerItem {
                VideoPlayerView(item: item, authService: authService)
                    .environmentObject(navigationManager)
            }
        }
    }
}

// MARK: - Home Tab Wrapper

struct HomeTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            if let vm = viewModel {
                HomeContentView(
                    viewModel: vm,
                    isSidebarVisible: .constant(false),
                    navigationManager: navigationManager
                )
                .navigationBarHidden(true)
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear {
                        initializeViewModel()
                    }
            }
        }
    }

    private func initializeViewModel() {
        guard viewModel == nil, let session = authService.currentSession else { return }

        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken
        let contentService = ContentService(apiClient: apiClient, authService: authService)

        viewModel = HomeViewModel(
            contentService: contentService,
            authService: authService,
            navigationCoordinator: nil,
            navigationManager: navigationManager,
            appState: appState
        )
    }
}

// MARK: - Search Tab Wrapper

struct SearchTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var viewModel: SearchViewModel?

    var body: some View {
        NavigationStack {
            if let vm = viewModel {
                SearchView(
                    viewModel: vm,
                    authService: authService,
                    coordinator: coordinator,
                    navigationManager: navigationManager
                )
                .navigationBarHidden(true)
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear {
                        initializeViewModel()
                    }
            }
        }
    }

    private func initializeViewModel() {
        guard viewModel == nil, let session = authService.currentSession else { return }

        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken
        let contentService = ContentService(apiClient: apiClient, authService: authService)

        viewModel = SearchViewModel(
            contentService: contentService,
            authService: authService,
            navigationCoordinator: coordinator
        )
    }
}

// MARK: - Library Tab Wrapper

struct LibraryTabViewWrapper: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var contentService: ContentService?

    var body: some View {
        NavigationStack {
            if let service = contentService {
                LibraryTabView(
                    contentService: service,
                    authService: authService,
                    navigationCoordinator: coordinator
                )
                .navigationBarHidden(true)
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear {
                        initializeServices()
                    }
            }
        }
    }

    private func initializeServices() {
        guard contentService == nil, let session = authService.currentSession else { return }

        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken
        contentService = ContentService(apiClient: apiClient, authService: authService)
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
    @EnvironmentObject var authService: AuthenticationService
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
        guard viewModel == nil, let session = authService.currentSession else { return }

        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken

        viewModel = ItemDetailViewModel(
            item: item,
            apiClient: apiClient,
            authService: authService,
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

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AuthenticationService())
}
