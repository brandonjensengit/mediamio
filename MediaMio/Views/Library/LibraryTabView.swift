//
//  LibraryTabView.swift
//  MediaMio
//
//  Main Library tab view with Movies/TV Shows categories
//

import SwiftUI

struct LibraryTabView: View {
    @StateObject private var viewModel: LibraryTabViewModel
    @EnvironmentObject private var navigationManager: NavigationManager
    /// Survives tab-switches because this view stays mounted in the
    /// ZStack — flipping back to Library does NOT re-fetch. The
    /// `ErrorView` retry button calls `loadLibraries()` directly, bypassing
    /// this flag, so a failed initial load can still be retried.
    @State private var hasLoaded = false

    init(
        contentService: ContentService,
        authService: AuthenticationService,
        navigationCoordinator: NavigationCoordinator?
    ) {
        _viewModel = StateObject(wrappedValue: LibraryTabViewModel(
            contentService: contentService,
            authService: authService,
            navigationCoordinator: navigationCoordinator
        ))
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView(message: "Loading libraries...")
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadLibraries()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Category Selector
                    CategorySelector(
                        selectedCategory: $viewModel.selectedCategory,
                        onCategorySelected: { category in
                            viewModel.selectCategory(category)
                        }
                    )
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                    // Library Content
                    if let currentViewModel = viewModel.currentViewModel {
                        LibraryView(viewModel: currentViewModel)
                    } else {
                        EmptyStateView(
                            systemImage: "film.stack",
                            title: "No Content in \(viewModel.selectedCategory.displayName)",
                            message: "Add some media to this library in Jellyfin"
                        )
                    }
                }
            }
        }
        // Library lives in `MainTabView`'s ZStack alongside Home, Search, and
        // Settings — all four tabs stay mounted so scroll/focus survive tab
        // switches. Without this gate, the `.task` fires at cold launch even
        // when Home is selected, paying for an unused /Items/Libraries fetch.
        // `.task(id:)` re-runs whenever the selected tab changes; we only
        // load when we're the active tab and haven't already loaded.
        .task(id: navigationManager.selectedTab) {
            guard navigationManager.selectedTab == .library else { return }
            guard !hasLoaded else { return }
            await viewModel.loadLibraries()
            if viewModel.errorMessage == nil {
                hasLoaded = true
            }
        }
    }
}

// MARK: - Category Selector

struct CategorySelector: View {
    @Binding var selectedCategory: LibraryCategory
    let onCategorySelected: (LibraryCategory) -> Void

    @FocusState private var focusedCategory: LibraryCategory?
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 60) {
            ForEach(LibraryCategory.allCases) { category in
                CategoryTab(
                    category: category,
                    isSelected: selectedCategory == category,
                    action: {
                        onCategorySelected(category)
                    }
                )
                .focused($focusedCategory, equals: category)
                .background(
                    // Animated underline
                    VStack {
                        Spacer()
                        if selectedCategory == category {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 6)
                                .matchedGeometryEffect(id: "underline", in: animation)
                        }
                    }
                )
            }

            Spacer()
        }
        .padding(.horizontal, 60)
        .focusSection()  // Keep focus within this section
        .onAppear {
            focusedCategory = selectedCategory
        }
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let category: LibraryCategory
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.system(size: 40, weight: isSelected ? .bold : .semibold))
                .foregroundColor(textColor)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isFocused {
            return .white.opacity(0.8)
        } else {
            return .white.opacity(0.5)
        }
    }
}
