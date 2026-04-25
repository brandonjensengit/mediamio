//
//  LibraryView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var navigationManager: NavigationManager

    // Focus state
    @FocusState private var toolbarFocus: LibraryToolbar.ToolbarField?

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 40)
    ]

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

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
                EmptyStateView(
                    systemImage: "film.stack",
                    title: "No Content in \(viewModel.title)",
                    message: "Add some media to this library in Jellyfin"
                )
            } else {
                // Content
                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Toolbar with title and sort
                            LibraryToolbar(
                                viewModel: viewModel,
                                focusedField: $toolbarFocus
                            )
                            .padding(.top, 40)

                            // Filter bar — each chip opens a native tvOS
                            // Menu inline on tap; no sheet presentations.
                            LibraryFilterBar(viewModel: viewModel)
                                .padding(.bottom, 20)

                            // Grid of items
                            LazyVGrid(columns: columns, spacing: 60) {
                                ForEach(viewModel.items) { item in
                                    PosterCard(
                                        item: item,
                                        baseURL: viewModel.baseURL
                                    ) {
                                        // Use NavigationManager.showDetail
                                        // (full-screen cover) — the legacy
                                        // viewModel.selectItem path appended
                                        // to a NavigationCoordinator path
                                        // that nothing observed, so Select
                                        // looked dead.
                                        navigationManager.showDetail(for: item)
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

                    // A-Z rail — only meaningful under alphabetical sort.
                    if viewModel.sortOption == .alphabetical {
                        LetterJumpRail(viewModel: viewModel)
                            .frame(width: 70)
                            .padding(.trailing, 20)
                    }
                }
            }
        }
        .task {
            await viewModel.loadContent()
            await viewModel.loadFilterOptions()
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
                        .background(Constants.Colors.surface2)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Letter Jump Rail

/// Vertical A-Z strip that filters the library by SortName prefix. On tvOS
/// focus, the active letter highlights; on tap, the VM reloads the library
/// restricted to that letter — this is true filtering, not scroll-to-anchor,
/// because the library is paginated and later letters may not be loaded yet.
/// "#" maps to Jellyfin's digit/symbol bucket. "All" clears the filter.
private struct LetterJumpRail: View {
    @ObservedObject var viewModel: LibraryViewModel

    private static let letters: [String] =
        ["All", "#"] + (65...90).map { String(UnicodeScalar($0)!) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Self.letters, id: \.self) { letter in
                    LetterButton(
                        letter: letter,
                        isActive: isActive(letter)
                    ) {
                        let target: String? = (letter == "All") ? nil : letter
                        Task { await viewModel.jumpToLetter(target) }
                    }
                }
            }
            .padding(.vertical, 40)
        }
        .focusSection()
    }

    private func isActive(_ letter: String) -> Bool {
        if letter == "All" { return viewModel.activeLetter == nil }
        return viewModel.activeLetter == letter
    }
}

private struct LetterButton: View {
    let letter: String
    let isActive: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            Text(letter == "All" ? "•" : letter)
                .font(letter == "All" ? .title : .headline)
                .fontWeight(isActive ? .bold : .regular)
                .foregroundColor(foreground)
                .frame(width: 50, height: letter == "All" ? 44 : 36)
                .background(background)
                .cornerRadius(8)
                .scaleEffect(isFocused ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isActive { return .black }
        if isFocused { return .white }
        return .white.opacity(0.6)
    }

    private var background: Color {
        if isActive { return .white }
        if isFocused { return .white.opacity(0.25) }
        return .clear
    }
}

// MARK: - Empty State

// MARK: - Preview

#Preview {
    let mockSection = ContentSection(
        title: "Movies",
        items: [],
        type: .library(id: "1", name: "Movies", collectionType: "movies")
    )

    let apiClient = JellyfinAPIClient()
    let authService = AuthenticationService(apiClient: apiClient)
    let contentService = ContentService(apiClient: apiClient, authService: authService)
    let viewModel = LibraryViewModel(
        section: mockSection,
        contentService: contentService,
        authService: authService
    )

    LibraryView(viewModel: viewModel)
}
