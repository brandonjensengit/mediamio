//
//  SearchView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    var navigationManager: NavigationManager? = nil
    @EnvironmentObject var env: AppEnvironment
    @FocusState private var isSearchFieldFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 40)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Header
                SearchHeader(viewModel: viewModel, isSearchFieldFocused: $isSearchFieldFocused)
                    .padding(.horizontal, Constants.UI.defaultPadding)
                    .padding(.top, 40)
                    .padding(.bottom, 30)

                // Content
                if viewModel.isInitialState {
                    // Initial state — show recents if we have any, else the
                    // "search your library" hint.
                    if viewModel.recentSearches.isEmpty {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            title: "Search Your Library",
                            message: "Find movies, TV shows, and more"
                        )
                    } else {
                        RecentSearchesView(viewModel: viewModel)
                    }
                } else if viewModel.isSearching && !viewModel.hasResults {
                    // Searching for first time
                    LoadingView(message: "Searching...")
                } else if let error = viewModel.errorMessage {
                    // Error state
                    ErrorView(message: error) {
                        // Retry not needed - search will retry automatically
                    }
                } else if viewModel.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No Results Found",
                        message: "No results for \"\(viewModel.searchQuery)\". Try different keywords."
                    )
                } else {
                    // Results
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 30) {
                            // Results count
                            if !viewModel.statusText.isEmpty {
                                HStack {
                                    Text(viewModel.statusText)
                                        .font(.title3)
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                                .padding(.horizontal, Constants.UI.defaultPadding)
                            }

                            // Results grid
                            LazyVGrid(columns: columns, spacing: 60) {  // Increased spacing for scale room
                                ForEach(viewModel.results) { item in
                                    NavigationLink(destination: ItemDetailViewWrapper(
                                        item: item,
                                        authService: authService,
                                        coordinator: coordinator,
                                        navigationManager: navigationManager,
                                        env: env
                                    )) {
                                        PosterCard(
                                            item: item,
                                            baseURL: viewModel.baseURL
                                        ) {
                                            print("🔍 Search result tapped: \(item.name)")
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 20)  // Vertical padding to prevent clipping
                                    .onAppear {
                                        // Load more when approaching end
                                        if item == viewModel.results.last {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                    }
                                }

                                // Loading more indicator
                                if viewModel.isLoadingMore {
                                    VStack(spacing: 20) {
                                        ProgressView()
                                            .scaleEffect(1.5)

                                        Text("Loading more...")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .gridCellColumns(columns.count)
                                }
                            }
                            .padding(.horizontal, Constants.UI.defaultPadding)
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Auto-focus search field when view appears
            isSearchFieldFocused = true
        }
    }
}

// MARK: - Search Header

struct SearchHeader: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Search")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 30) {
                // Search field
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    TextField("Search for movies, TV shows...", text: $viewModel.searchQuery)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                            isSearchFieldFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .frame(maxWidth: 1200)

                // Filter menu
                Menu {
                    ForEach(SearchViewModel.FilterType.allCases) { filter in
                        Button {
                            viewModel.changeFilter(filter)
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if viewModel.filterType == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(viewModel.filterType.rawValue)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Image(systemName: "chevron.down")
                            .font(.title3)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Recent Searches

/// Shown in place of the "Search Your Library" empty state when the user has
/// search history. Each row replays the query in the search field; a Clear All
/// row wipes persisted history.
struct RecentSearchesView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var focusedQuery: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Recent Searches")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        viewModel.clearAllRecentSearches()
                    } label: {
                        Text("Clear All")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Constants.UI.defaultPadding)

                VStack(spacing: 12) {
                    ForEach(viewModel.recentSearches, id: \.self) { query in
                        RecentSearchRow(query: query) {
                            viewModel.runRecentSearch(query)
                        } onRemove: {
                            viewModel.removeRecentSearch(query)
                        }
                        .focused($focusedQuery, equals: query)
                    }
                }
                .padding(.horizontal, Constants.UI.defaultPadding)
                .padding(.bottom, 40)
            }
            .padding(.top, 20)
        }
    }
}

struct RecentSearchRow: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onTap) {
                HStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text(query)
                        .font(.title3)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "arrow.up.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
                .background(isFocused ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                .cornerRadius(Constants.UI.cornerRadius)
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            }
            .buttonStyle(.plain)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding(20)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    let authService = AuthenticationService()
    let apiClient = JellyfinAPIClient()
    let contentService = ContentService(apiClient: apiClient, authService: authService)
    let coordinator = NavigationCoordinator()
    let viewModel = SearchViewModel(
        contentService: contentService,
        authService: authService,
        navigationCoordinator: coordinator
    )

    SearchView(
        viewModel: viewModel,
        authService: authService,
        coordinator: coordinator,
        navigationManager: nil
    )
}
