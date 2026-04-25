//
//  SearchView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Unified focus targets for the Search screen. Using a single enum
/// (instead of separate `@FocusState<Bool>` for the field and grid) lets us
/// express focus transitions as "set `focus = .field`" or "set `focus = .result(0)`"
/// and SwiftUI's focus engine handles the binding updates in both directions —
/// the separate `@FocusState<Bool> + .onMoveCommand` approach got stuck because
/// programmatically setting the bound Bool to true didn't release cleanly on
/// the next user-driven move.
enum SearchFocus: Hashable {
    case field
    case result(Int)
}

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    let authService: AuthenticationService
    let coordinator: NavigationCoordinator
    @ObservedObject var navigationManager: NavigationManager
    @EnvironmentObject var env: AppEnvironment
    @FocusState private var focus: SearchFocus?

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 40)
    ]

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            // Everything lives inside ONE ScrollView — header AND results.
            // Earlier split-layout (header in outer VStack, results in its
            // own ScrollView) hit a tvOS focus-engine bug: single-result
            // Up-press from the lone grid cell escaped past the header
            // straight to the TopNavBar's "Home" chip. Programmatic fixes
            // (focusSection + prefersDefaultFocus + onMoveCommand reseating
            // focus) all created a different bug: focus got pinned to the
            // field, so Down was sticky. Making header+grid siblings in one
            // ScrollView routes focus via the ScrollView's own vertical
            // traversal, which is deterministic — no programmatic override
            // needed, and matches the native tvOS search pattern.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    SearchHeader(
                        viewModel: viewModel,
                        focus: $focus
                    )
                    .padding(.horizontal, Constants.UI.defaultPadding)
                    .padding(.top, 40)
                    .padding(.bottom, 30)

                    content
                }
            }
        }
        .onAppear { claimFieldFocus() }
        .onChange(of: navigationManager.selectedTab) { _, newTab in
            // SearchView is mounted once at app launch (MainTabView keeps all
            // four tabs alive in a ZStack via opacity flips), so .onAppear
            // only fires that one time — long before the user touches the
            // Search chip. React to the tab actually becoming .search to
            // claim focus on every entry.
            if newTab == .search {
                claimFieldFocus()
            }
        }
    }

    /// Defer the focus set so it lands after SwiftUI has finished applying
    /// the tab-switch state changes. A synchronous set loses the race against
    /// the TopNavBar chip's focus claim; 50ms is the smallest delay that
    /// wins reliably on the Apple TV 4K sim.
    private func claimFieldFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focus = .field
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isInitialState {
            if viewModel.recentSearches.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Search Your Library",
                    message: "Find movies, TV shows, and more"
                )
                .frame(minHeight: 400)
            } else {
                RecentSearchesView(viewModel: viewModel)
            }
        } else if viewModel.isSearching && !viewModel.hasResults {
            LoadingView(message: "Searching...")
                .frame(minHeight: 400)
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error) {}
                .frame(minHeight: 400)
        } else if viewModel.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "No Results Found",
                message: "No results for \"\(viewModel.searchQuery)\". Try different keywords."
            )
            .frame(minHeight: 400)
        } else {
            resultsGrid
        }
    }

    private var resultsGrid: some View {
        VStack(spacing: 30) {
            if !viewModel.statusText.isEmpty {
                HStack {
                    Text(viewModel.statusText)
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, Constants.UI.defaultPadding)
            }

            LazyVGrid(columns: columns, spacing: 60) {
                ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                    PosterCard(
                        item: item,
                        baseURL: viewModel.baseURL
                    ) {
                        navigationManager.showDetail(for: item)
                    }
                    .padding(.vertical, 20)
                    .onAppear {
                        if item == viewModel.results.last {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
                }

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
        // Grid gets a focus section so Down from the sticky-top search
        // field has an explicit destination region. Without this, focus
        // routing from the field straight into a lone grid cell on the
        // leading edge is unreliable — the field is full-width while the
        // cell is narrow on the left.
        .focusSection()
    }
}

// MARK: - Search Header

struct SearchHeader: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState.Binding var focus: SearchFocus?

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
                        .focused($focus, equals: .field)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                            focus = .field
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
                .background(Constants.Colors.surface1)
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
                    .background(Constants.Colors.surface2)
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
                .background(isFocused ? Constants.Colors.surface3 : Constants.Colors.surface1)
                .cornerRadius(Constants.UI.cornerRadius)
                .chromeFocus(isFocused: isFocused)
            }
            .buttonStyle(.cardChrome)

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
    let apiClient = JellyfinAPIClient()
    let authService = AuthenticationService(apiClient: apiClient)
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
        navigationManager: NavigationManager()
    )
}
