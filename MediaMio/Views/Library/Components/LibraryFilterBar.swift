//
//  LibraryFilterBar.swift
//  MediaMio
//
//  Horizontal filter bar for tvOS library browsing
//

import SwiftUI

struct LibraryFilterBar: View {
    @ObservedObject var viewModel: LibraryViewModel
    @FocusState.Binding var focusedField: FilterField?

    enum FilterField: Hashable {
        case genre
        case year
        case rating
        case status
        case clearAll
    }

    var body: some View {
        HStack(spacing: 20) {
            // Genre Filter
            FilterButton(
                title: "Genre",
                value: genreFilterText,
                isActive: !viewModel.filters.selectedGenres.isEmpty
            )
            .focused($focusedField, equals: .genre)

            // Year Filter
            FilterButton(
                title: "Year",
                value: viewModel.filters.yearRange?.displayText ?? "Any",
                isActive: viewModel.filters.yearRange != nil
            )
            .focused($focusedField, equals: .year)

            // Rating Filter
            FilterButton(
                title: "Rating",
                value: ratingFilterText,
                isActive: viewModel.filters.minimumRating > 0
            )
            .focused($focusedField, equals: .rating)

            // Watched Status Filter
            FilterButton(
                title: "Status",
                value: statusFilterText,
                isActive: !viewModel.filters.showWatched || !viewModel.filters.showUnwatched
            )
            .focused($focusedField, equals: .status)

            // Clear All (only show if filters active)
            if viewModel.filters.isActive {
                Button(action: {
                    Task {
                        await viewModel.clearFilters()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear All")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.card)
                .focused($focusedField, equals: .clearAll)
            }

            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .focusSection()  // Keep focus within filter section
    }

    // MARK: - Computed Properties

    private var genreFilterText: String {
        let count = viewModel.filters.selectedGenres.count
        if count == 0 {
            return "All"
        } else if count == 1 {
            return viewModel.filters.selectedGenres.first?.displayName ?? "All"
        } else {
            return "\(count) selected"
        }
    }

    private var ratingFilterText: String {
        let rating = viewModel.filters.minimumRating
        if rating > 0 {
            return String(format: "%.1f+", rating)
        }
        return "Any"
    }

    private var statusFilterText: String {
        let watched = viewModel.filters.showWatched
        let unwatched = viewModel.filters.showUnwatched

        if watched && unwatched {
            return "All"
        } else if watched {
            return "Watched"
        } else if unwatched {
            return "Unwatched"
        } else {
            return "None"
        }
    }
}

// MARK: - Filter Button Component

struct FilterButton: View {
    let title: String
    let value: String
    let isActive: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: {
            // Action handled by parent via focused() binding
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.headline)
                    .foregroundColor(isActive ? .white : .primary)
            }
            .frame(minWidth: 140)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var backgroundColor: Color {
        if isFocused {
            return Color.white.opacity(0.15)
        } else if isActive {
            return Color.accentColor.opacity(0.3)
        } else {
            return Color.white.opacity(0.05)
        }
    }
}
