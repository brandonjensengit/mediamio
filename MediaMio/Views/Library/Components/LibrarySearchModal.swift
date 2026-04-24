//
//  LibrarySearchModal.swift
//  MediaMio
//
//  Search modal for searching within a library
//

import SwiftUI

struct LibrarySearchModal: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var searchResults: [MediaItem] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    @FocusState private var isSearchFieldFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 30)
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Header
                searchHeader
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    .padding(.bottom, 30)

                // Search Results or Empty State
                if isSearching {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Searching...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if let error = errorMessage {
                    // Error state
                    ErrorView(message: error) {
                        Task {
                            await performSearch()
                        }
                    }
                } else if searchQuery.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "Search \(viewModel.title)",
                        message: "Enter a title to search within this library",
                        iconOpacity: 0.3
                    )
                } else if searchResults.isEmpty {
                    EmptyStateView(
                        systemImage: "film.stack",
                        title: "No Results Found",
                        message: "Try a different search term",
                        iconOpacity: 0.3
                    )
                } else {
                    // Results
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(searchResults) { item in
                                PosterCard(
                                    item: item,
                                    baseURL: viewModel.baseURL
                                ) {
                                    // Select item and dismiss search
                                    viewModel.selectItem(item)
                                    dismiss()
                                }
                                .padding(.vertical, 15)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .onAppear {
            // Focus search field on appear
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 30) {
            // Search field
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.secondary)

                TextField("Search in \(viewModel.title)", text: $searchQuery)
                    .font(.title3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchQuery) { _, newValue in
                        // Debounced search
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                            if searchQuery == newValue && !newValue.isEmpty {
                                await performSearch()
                            } else if newValue.isEmpty {
                                searchResults = []
                            }
                        }
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(Constants.Colors.surface2)
            .cornerRadius(12)

            // Close button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Search

    private func performSearch() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            searchResults = try await viewModel.searchLibrary(query: searchQuery, limit: 100)
        } catch {
            print("❌ Search failed: \(error)")
            errorMessage = "Search failed: \(error.localizedDescription)"
        }

        isSearching = false
    }
}
