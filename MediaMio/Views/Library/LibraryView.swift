//
//  LibraryView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel

    // Focus state
    @FocusState private var filterFocus: LibraryFilterBar.FilterField?
    @FocusState private var toolbarFocus: LibraryToolbar.ToolbarField?

    // Modal state
    @State private var showGenrePicker = false
    @State private var showYearPicker = false
    @State private var showRatingPicker = false
    @State private var showStatusPicker = false
    @State private var showSearch = false

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 40)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading && !viewModel.hasContent {
                // Initial loading
                LoadingView(message: "Loading library...")
            } else if let error = viewModel.errorMessage {
                // Error state
                ErrorView(message: error) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            } else if viewModel.isEmpty {
                // Empty state
                EmptyLibraryView(libraryName: viewModel.title)
            } else {
                // Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Toolbar with title, sort, and search
                        LibraryToolbar(
                            viewModel: viewModel,
                            showSearch: $showSearch,
                            focusedField: $toolbarFocus
                        )
                        .padding(.top, 40)

                        // Filter bar
                        LibraryFilterBar(
                            viewModel: viewModel,
                            focusedField: $filterFocus
                        )
                        .padding(.bottom, 20)
                        .onChange(of: filterFocus) { _, newValue in
                            handleFilterFocusChange(newValue)
                        }

                        // Grid of items
                        LazyVGrid(columns: columns, spacing: 60) {
                            ForEach(viewModel.items) { item in
                                PosterCard(
                                    item: item,
                                    baseURL: viewModel.baseURL
                                ) {
                                    viewModel.selectItem(item)
                                }
                                .padding(.vertical, 20)
                                .onAppear {
                                    // Load more when approaching end
                                    if item == viewModel.items.last {
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
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .task {
            await viewModel.loadContent()
            await viewModel.loadFilterOptions()
        }
        .sheet(isPresented: $showGenrePicker) {
            GenrePickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showYearPicker) {
            YearRangePickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showRatingPicker) {
            RatingPickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showStatusPicker) {
            StatusPickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showSearch) {
            LibrarySearchModal(viewModel: viewModel)
        }
    }

    // MARK: - Filter Focus Handling

    private func handleFilterFocusChange(_ field: LibraryFilterBar.FilterField?) {
        guard let field = field else { return }

        switch field {
        case .genre:
            showGenrePicker = true
        case .year:
            showYearPicker = true
        case .rating:
            showRatingPicker = true
        case .status:
            showStatusPicker = true
        case .clearAll:
            break // Button action handles this
        }
    }
}

// MARK: - Library Header

struct LibraryHeader: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text(viewModel.title)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)

            // Sort controls and item count
            HStack(spacing: 40) {
                // Item count
                Text(viewModel.statusText)
                    .font(.title3)
                    .foregroundColor(.secondary)

                Spacer()

                // Sort picker
                HStack(spacing: 16) {
                    Text("Sort by:")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Menu {
                        ForEach(LibraryViewModel.SortOption.allCases) { option in
                            Button {
                                Task {
                                    await viewModel.changeSortOption(option)
                                }
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(viewModel.sortOption.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Image(systemName: "chevron.down")
                                .font(.title3)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyLibraryView: View {
    let libraryName: String

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Content in \(libraryName)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Add some media to this library in Jellyfin")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockSection = ContentSection(
        title: "Movies",
        items: [],
        type: .library(id: "1", name: "Movies")
    )

    let authService = AuthenticationService()
    let apiClient = JellyfinAPIClient()
    let contentService = ContentService(apiClient: apiClient, authService: authService)
    let viewModel = LibraryViewModel(
        section: mockSection,
        contentService: contentService,
        authService: authService
    )

    LibraryView(viewModel: viewModel)
}
