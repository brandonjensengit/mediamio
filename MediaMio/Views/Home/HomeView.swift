//
//  HomeView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()

                if let vm = viewModel {
                    HomeContentView(viewModel: vm)
                        .navigationDestination(for: MediaItem.self) { item in
                            createItemDetailView(for: item)
                        }
                } else {
                    LoadingView(message: "Initializing...")
                }
            }
            .onAppear {
                if viewModel == nil, let session = authService.currentSession {
                    // Initialize ViewModel with dependencies
                    let apiClient = createAPIClient(for: session)
                    let contentService = ContentService(apiClient: apiClient, authService: authService)
                    viewModel = HomeViewModel(
                        contentService: contentService,
                        authService: authService,
                        navigationCoordinator: coordinator
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func createItemDetailView(for item: MediaItem) -> some View {
        ItemDetailViewWrapper(item: item, authService: authService, coordinator: coordinator)
    }

    private func createAPIClient(for session: UserSession) -> JellyfinAPIClient {
        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken
        return apiClient
    }
}

// MARK: - Item Detail Wrapper

struct ItemDetailViewWrapper: View {
    let item: MediaItem
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    @StateObject private var viewModel: ItemDetailViewModel

    init(item: MediaItem, authService: AuthenticationService, coordinator: NavigationCoordinator) {
        self.item = item
        self.authService = authService
        self.coordinator = coordinator

        // Create ViewModel once and keep it alive
        let session = authService.currentSession!
        let apiClient = JellyfinAPIClient()
        apiClient.baseURL = session.serverURL
        apiClient.accessToken = session.accessToken

        _viewModel = StateObject(wrappedValue: ItemDetailViewModel(
            item: item,
            apiClient: apiClient,
            authService: authService,
            navigationCoordinator: coordinator
        ))
    }

    var body: some View {
        ItemDetailView(viewModel: viewModel)
    }
}

// MARK: - Navigation Coordinator

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()

    func navigate(to item: MediaItem) {
        print("🧭 Navigating to: \(item.name)")
        navigationPath.append(item)
    }
}

// MARK: - Home Content View

struct HomeContentView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ZStack {
            if viewModel.isLoading && !viewModel.hasContent {
                // Initial loading state
                LoadingView(message: "Loading your media...")
            } else if let error = viewModel.errorMessage {
                // Error state
                ErrorView(message: error) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            } else if viewModel.isEmpty {
                // Empty state
                EmptyHomeView()
            } else {
                // Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Hero Banner
                        if let featured = viewModel.featuredItem {
                            HeroBanner(
                                item: featured,
                                baseURL: viewModel.baseURL
                            ) {
                                viewModel.playItem(featured)
                            } onInfo: {
                                viewModel.showItemDetails(featured)
                            }
                        }

                        // Content Sections
                        VStack(spacing: Constants.UI.sectionSpacing) {
                            ForEach(viewModel.sections) { section in
                                ContentRow(
                                    section: section,
                                    baseURL: viewModel.baseURL
                                ) { item in
                                    viewModel.selectItem(item)
                                } onSeeAll: {
                                    viewModel.showSeeAll(for: section)
                                }
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 60)
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

struct EmptyHomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Content Yet")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Add some media to your Jellyfin libraries to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
        }
    }
}

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

#Preview {
    HomeView()
        .environmentObject(AuthenticationService())
}
