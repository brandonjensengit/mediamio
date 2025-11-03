//
//  SearchView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
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
                    // Initial state - show instructions
                    SearchEmptyState()
                } else if viewModel.isSearching && !viewModel.hasResults {
                    // Searching for first time
                    LoadingView(message: "Searching...")
                } else if let error = viewModel.errorMessage {
                    // Error state
                    ErrorView(message: error) {
                        // Retry not needed - search will retry automatically
                    }
                } else if viewModel.isEmpty {
                    // No results
                    NoResultsView(query: viewModel.searchQuery)
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
                            LazyVGrid(columns: columns, spacing: 50) {
                                ForEach(viewModel.results) { item in
                                    PosterCard(
                                        item: item,
                                        baseURL: viewModel.baseURL
                                    ) {
                                        viewModel.selectItem(item)
                                    }
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

// MARK: - Empty States

struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("Search Your Library")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Find movies, TV shows, and more")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct NoResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Results Found")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("No results for \"\(query)\"")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)

                Text("Try searching with different keywords")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let authService = AuthenticationService()
    let apiClient = JellyfinAPIClient()
    let contentService = ContentService(apiClient: apiClient, authService: authService)
    let viewModel = SearchViewModel(
        contentService: contentService,
        authService: authService
    )

    SearchView(viewModel: viewModel)
}
